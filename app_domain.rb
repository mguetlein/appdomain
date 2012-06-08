
require 'euclidean_distance.rb'

set :lock, true

class String
  def to_boolean
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.nil? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: '#{self}'")
  end
end

module AppDomain
  
  class AppDomainModel < Ohm::Model 
    
    attribute :date
    attribute :creator
    attribute :app_domain_alg
    attribute :algorithm_params
    attribute :training_dataset_uri
    attribute :prediction_feature
    attribute :independent_features_yaml
    attribute :predicted_datasets_yaml
    attribute :model_yaml
    attribute :finished
    
    index :app_domain_alg
    index :prediction_feature
    index :training_dataset_uri
    index :finished
    
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
        app_domain_alg and app_domain_alg =~ /EuclideanDistance/
    end

    def find_predicted_model(dataset_uri)
      predicted_datasets[dataset_uri] 
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
      model = super params
      model.subjectid = subjectid
      model
    end
    
    def build(waiting_task=nil)
      case self.app_domain_alg
      when /EuclideanDistance/
        dataset = OpenTox::Dataset.find(self.training_dataset_uri)
        features = dataset.features.keys - [ self.prediction_feature ]
        raise "no features in dataset" if features.size==0 
        self.model_yaml = AppDomain::EuclideanDistance.new(dataset, dataset, features).to_yaml
      end
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
      LOGGER.debug metadata.to_yaml
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
    
    def apply(dataset_uri, waiting_task=nil)
      
      model = YAML.load(model_yaml)
      test_dataset = OpenTox::Dataset.find(dataset_uri)
      dataset = OpenTox::Dataset.create(CONFIG[:services]["opentox-dataset"],subjectid)
      metadata = { DC.creator => self.uri, OT.hasSource => dataset_uri }  
      dataset.add_metadata(metadata)
      test_dataset.compounds.each{|c| dataset.add_compound(c)}
      predicted_feature = File.join( uri, "predicted", "value")
      dataset.add_feature(predicted_feature)
      count = 0
      test_dataset.compounds.each do |c|
        dataset.add(c,predicted_feature,model.ad(c,test_dataset))
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