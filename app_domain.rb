
require 'euclidean_distance.rb'
require 'fingerprint.rb'
require 'open3'

set :lock, true

@@modeldir = "model"

class String
  def to_boolean
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.nil? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: '#{self}'")
  end
end

module ZipUtil
  
  def self.zip(zip_file, file)
    LOGGER.debug "zipping #{zip_file}"
    stdin, stdout, stderr = Open3.popen3("/usr/bin/zip -D #{zip_file} #{file}")
    LOGGER.debug stdout.readlines.collect{|l| l.chomp}.join(";")
    LOGGER.debug stderr.readlines.collect{|l| l.chomp}.join(";")
    stdout.close
    stderr.close
    stdin.close
    raise "could not zip file" unless File.exist?(zip_file)
    File.delete(file)
  end
  
  def self.unzip(zip_file, dir)
    LOGGER.debug "unzipping #{zip_file}"
    raise "no zip file found" unless File.exist?(zip_file)
    stdin, stdout, stderr = Open3.popen3("/usr/bin/unzip -nj #{zip_file} -d #{dir}")
    LOGGER.debug stdout.readlines.collect{|l| l.chomp}.join(";")
    LOGGER.debug stderr.readlines.collect{|l| l.chomp}.join(";")
    stdout.close
    stderr.close
    stdin.close
  end
  
end

module AppDomain
  
  class AppDomainModel < Ohm::Model 
    
    attribute :date
    attribute :creator
    attribute :app_domain_alg
    attribute :app_domain_params
    attribute :training_dataset_uri
    attribute :prediction_feature
    attribute :independent_features_yaml
    attribute :predicted_datasets_yaml
    attribute :model_yaml
    attribute :finished
    attribute :weight_model_uri
    
    index :app_domain_alg
    index :app_domain_params
    index :prediction_feature
    index :training_dataset_uri
    index :finished
    index :weight_model_uri
    
    attr_accessor :subjectid
    
    def independent_features
      self.independent_features_yaml ? YAML.load(self.independent_features_yaml) : []
    end
    
    def independent_features=(array)
      self.independent_features_yaml = array.to_yaml
    end
    
    def predicted_datasets
      self.predicted_datasets_yaml ? YAML.load(self.predicted_datasets_yaml) : {}
    end
    
    def predicted_datasets=(hash)
      self.predicted_datasets_yaml = hash.to_yaml
    end
    
    def self.check_app_domain_alg(app_domain_alg)
      raise OpenTox::BadRequestError.new("unknown app-domain alg #{app_domain_alg}") unless
        app_domain_alg and app_domain_alg =~ /EuclideanDistance|Fingerprint/ 
    end
    
    def split_app_domain_params()
      res = {}
      self.app_domain_params.split(";").each do |alg_params|
        alg_param = alg_params.split("=",2)
        raise OpenTox::BadRequestError.new "invalid algorithm param: '"+alg_params.to_s+"'" unless alg_param.size==2 or alg_param[0].to_s.size<1 or alg_param[1].to_s.size<1
        LOGGER.warn "algorihtm param contains empty space, encode? "+alg_param[1].to_s if alg_param[1] =~ /\s/
        res[alg_param[0].to_sym] = alg_param[1]
      end if self.app_domain_params
      res
    end    

    def find_predicted_dataset(dataset_uri)
      if self.predicted_datasets[dataset_uri]
        if OpenTox::Dataset.exist?(predicted_datasets[dataset_uri])
          self.predicted_datasets[dataset_uri]
        else
          hash = self.predicted_datasets
          hash.delete(dataset_uri)
          self.predicted_datasets = hash
          self.save
          nil
        end
      else
        nil
      end
    end
    
    def self.find_model(params)
      p = {}
      params.keys.each do |k|
        key = k.to_s
        if key=="dataset_uri"
          p[:training_dataset_uri] = params[k]
        else  
          p[key.to_sym] = params[k]
        end
      end
      p[:finished] = true
      #puts p.to_yaml
      [:splat,:captures].each{|k| p.delete(k)}
      set = AppDomain::AppDomainModel.find(p)
      if (set.size==0)
        nil
      else
        set.collect.last.uri # collect to convert Ohm:set in order to apply .last
      end
    end
    
    def self.create(params={}, subjectid=nil)
      check_app_domain_alg(params[:app_domain_alg])
      params[:date] = Time.new
      params[:creator] = AA_SERVER ? OpenTox::Authorization.get_user(subjectid) : "unknown"
      params[:training_dataset_uri] = params.delete("dataset_uri")
      params[:finished] = false
      ["splat","captures"].each{|k| params.delete(k)}
      model = super params
      model.subjectid = subjectid
      model
    end
    
    def self.feature_weights(weight_model_uri)
      feature_weights_str = OpenTox::RestClientWrapper.get(weight_model_uri+"/weights")
      feature_weights = {}
      feature_weights_str.split("\n").each do |line|
        vals = line.split(" ")
        feature_weights[vals[0].to_s] = vals[1].to_f
      end
      feature_weights
    end
    
    def build(waiting_task=nil)
      dataset = OpenTox::Dataset.find(self.training_dataset_uri)
      features = dataset.features.keys - [ self.prediction_feature ]
      feature_weights = self.weight_model_uri ? AppDomainModel.feature_weights(self.weight_model_uri) : nil
      raise "no features in dataset" if features.size==0
      case self.app_domain_alg 
      when /EuclideanDistance/
        m_yaml = AppDomain::EuclideanDistance.new(dataset, dataset, features, self.split_app_domain_params(), feature_weights).to_yaml
      when /Fingerprint/
        m_yaml = AppDomain::FingerprintModel.new(dataset, dataset, features, self.split_app_domain_params(), feature_weights ).to_yaml
      end
      store_m_yaml(m_yaml)
      self.finished = true
      self.save
    end
    
    def metadata
      value_feature_uri = File.join( uri, "predicted", "value")
      features = [value_feature_uri]
      { DC.title => "#{app_domain_alg} AppDomain Model",
        DC.creator => creator, 
        OT.trainingDataset => training_dataset_uri, 
        OT.dependentVariables => prediction_feature,
        OT.predictedVariables => features,
        OT.independentVariables => ["n/a"],#independent_features,
        OT.featureDataset => training_dataset_uri,#feature_dataset_uri,
      }
    end
    
    def to_rdf
      s = OpenTox::Serializer::Owl.new
      #LOGGER.debug metadata.to_yaml
      s.add_model(uri,metadata)
      s.to_rdfxml
    end    
    
    def prediction_value_feature
      feature = OpenTox::Feature.new File.join( uri, "predicted", "value")
      feature.add_metadata( {
        RDF.type => [OT.ModelPrediction, OT.NumericFeature ],
        OT.hasSource => uri,
        DC.creator => uri,
        DC.title => "AppDomain prediction",
      })
      feature
    end
    
    def model_file
      @@modeldir+"/"+self.id+".model"
    end

    def model_zip_file
      "#{self.model_file()}.zip"
    end

    def migrate_to_filesystem()
      raise "model dir missing" unless File.exist?(@@modeldir)
      if self.model_yaml!=nil and self.model_yaml.to_s.length>0
        File.open(model_file,"w+"){|f| f.puts model_yaml}
        ZipUtil.zip(model_zip_file(),model_file())
        m_yaml = load_m_yaml 
        raise m_yaml+" \n!=\n "+self.model_yaml unless m_yaml==self.model_yaml
        self.model_yaml=nil
        self.save
      end
    end
    
    def store_m_yaml(m_yaml)
      File.open(model_file,"w+"){|f| f.puts m_yaml}
      ZipUtil.zip(model_zip_file(),model_file())
    end
    
    def load_m_yaml
      ZipUtil.unzip(model_zip_file,@@modeldir) unless File.exist?(model_file()) 
      raise "could not unzip file" unless File.exist?(self.model_file())
      yaml = IO.readlines(model_file).join("")
      File.delete(model_file()) if File.exist?(self.model_zip_file())
      yaml
    end
          
    def apply(dataset_uri, waiting_task=nil)
      
      model = YAML.load(load_m_yaml)
      test_dataset = OpenTox::Dataset.find(dataset_uri)
      dataset = OpenTox::Dataset.create(CONFIG[:services]["opentox-dataset"],subjectid)
      metadata = { DC.creator => self.uri, OT.hasSource => dataset_uri }  
      dataset.add_metadata(metadata)
      test_dataset.compounds.each{|c| dataset.add_compound(c)}
      predicted_feature = File.join( uri, "predicted", "value")
      dataset.add_feature(predicted_feature)
      count = 0
      test_dataset.compounds.each do |c|
        dataset.add(c,predicted_feature,model.ad(c,test_dataset),true)
      end
      dataset.save(subjectid)
      
      predicted = self.predicted_datasets
      predicted[dataset_uri] = dataset.uri
      self.predicted_datasets = predicted
      self.save
      dataset.uri
    end
    
    def uri
      raise "no id" if self.id==nil
      $url_provider.url_for("/"+self.app_domain_alg+"/"+self.id.to_s, :full)
    end
    
  end
  
end