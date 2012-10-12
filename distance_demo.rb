require "rubygems"
require "opentox-ruby"
#require "euclidean_distance.rb"
#require "leverage_model.rb"
#require "fingerprint.rb"
require "app_domain.rb"

LOGGER = OTLogger.new(STDOUT)
LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
LOGGER.formatter = Logger::Formatter.new

METHOD = "fingerprint"

class Exception
  def message
    errorCause ? errorCause.to_yaml : to_s
  end
end


def self.demo1(dataset1, dataset2, alg_uri=nil, prediction_feature=nil)
  #features = dataset1.features.keys[0..9]
  features = nil# dataset1.features.keys #[0..4]
  
  weight_model_uri = nil
  if alg_uri
    algorithm = OpenTox::Algorithm::Generic.new(alg_uri)
    params = { :dataset_uri => dataset1.uri, :prediction_feature => prediction_feature }
    weight_model_uri = algorithm.run(params)
    puts weight_model_uri
  end
  feature_weights = weight_model_uri ? AppDomain::AppDomainModel.feature_weights(weight_model_uri) : nil
  puts feature_weights.to_yaml
  
  features = dataset1.features.keys unless features
  puts features.inspect
  if prediction_feature and features.include?(prediction_feature)
      features -= [prediction_feature]
      puts "removing prediction feature from ad-features"
  end  
  
  case METHOD
  when "leverage"    
    alg = AppDomain::LeverageModel.new(dataset1, dataset1, features)
  when "fingerprint"
    alg = AppDomain::FingerprintModel.new(dataset1, dataset1, features, {:method=>"consensus"})
    alg_w = AppDomain::FingerprintModel.new(dataset1, dataset1, features, {:method=>"consensus"}, feature_weights) if feature_weights
  else
    alg = AppDomain::EuclideanDistance.new(dataset1, dataset1, features, {:inflection_point=>2})
    alg_w = AppDomain::EuclideanDistance.new(dataset1, dataset1, features, {:inflection_point=>2}, feature_weights) if feature_weights
  end
    
  #puts alg.to_yaml
  
  puts "ad demo - merge datasets ..."
  
  data = OpenTox::Dataset.create
  featureD = "http://dataset"
  data.add_feature(featureD)
  
  [dataset1, dataset2].each do |d|
    d.compounds.each{|c| data.add_compound(c)}
    i = 0
    features.each do |f,m|
      #puts "ad demo - features #{i}/#{features.size}"
      i += 1
      data.add_feature(f,m)
      d.compounds.each do |c|
        d.data_entries[c][f].each do |v|
          data.add(c,f,v,true)
        end if d.data_entries[c][f]
      end
    end
    d.compounds.each do |c|
      data.add(c,featureD,d==dataset1 ? "dataset1" : "dataset2",true)
    end
  end
  
  puts "ad demo - merge datasets ... done"

  feature = "http://ad-feature"
  data.add_feature(feature)
  if (alg_w)
    feature_w = "http://ad-feature-weighted"
    data.add_feature(feature_w)
  end
  dataset2.compounds.each do |c|
    ad = alg.ad(c, dataset2)
    ad_w = alg_w.ad(c, dataset2) if alg_w
    puts "AD "+ad.to_s+(alg_w ? "\tw "+ad_w.to_s : "")
    data.add(c,feature,ad,true)
    data.add(c,feature_w,ad_w,true) if alg_w
  end
  
#  data.save
#  data
#  puts data.uri
#  
  filename = "/tmp/data#{data.uri.split("/")[-1]}.csv"
  File.open(filename, 'w') {|f| f.write(data.to_csv) }
  puts filename
  data.delete
end

def self.demo2(dataset)
  features = dataset.features.keys #[0..4]
  compounds = dataset.compounds #[0..99]
  
  data = OpenTox::Dataset.create
  compounds.each{|c| data.add_compound(c)}
  features.each do |f|
    data.add_feature(f,dataset.features[f])
    compounds.each do |c|
      dataset.data_entries[c][f].each do |v|
        data.add(c,f,v,true)
      end if dataset.data_entries[c][f]
    end
  end
  feature = "http://ad-feature"
  data.add_feature(feature)
  
  count = 0 
  compounds.each do |c|
    tmpDataset = OpenTox::Dataset.new
    compounds.each do |c2|
      tmpDataset.add_compound(c2) if c!=c2
    end
    case METHOD
    when "leverage"    
      alg = AppDomain::LeverageModel.new(tmpDataset, dataset)
    when "fingerprint"
      alg = AppDomain::FingerprintModel.new(tmpDataset, dataset, nil, {:method=>"knn"})
    else
      alg = AppDomain::EuclideanDistance.new(tmpDataset, dataset, features.size==dataset.features.size ? nil : features, {:inflection_point=>2})
    end    
    ad = alg.ad(c, dataset)
    puts "AD for compound #{count+1}/#{compounds.size}: #{ad}"
    exit
    count+=1
    data.add(c,feature,ad,true)
  end
  
  data.save
  data
  puts data.uri
  
  filename = "/tmp/data#{data.uri.split("/")[-1]}.csv"
  File.open(filename, 'w') {|f| f.write(data.to_csv) }
  puts filename
  data.delete
end

#dataset_uri = "http://local-ot/dataset/1623"#kazius 250 ob
#dataset_uri = "http://local-ot/dataset/11969" # kazius_250_13
#dataset_uri = "http://local-ot/dataset/12034" # kazius 250 split to 82 compounds, 282 bbrc feature
#dataset_uri = "http://local-ot/dataset/12084" #kazius 249, 530 bbrc


#res = OpenTox::RestClientWrapper.post("http://local-ot/validation/plain_training_test_split",
#  {:dataset_uri=>dataset_uri,:split_ratio=>0.995,:stratified=>"false"})
#puts res
#exit

# kazius 250, split 0.3-0.7
dataset_uri_1 = "http://local-ot/dataset/12297"
dataset_uri_2 = "http://local-ot/dataset/12298"
alg_uri = "http://local-ot/weka/RandomForest"
prediction_feature = "http://local-ot/dataset/11592/feature/endpoint"

# kazius 2features 250, split 0.3-0.7
dataset_uri_1 = "http://local-ot/dataset/12311"
dataset_uri_2 = "http://local-ot/dataset/12312"
alg_uri = "http://local-ot/weka/RandomForest"
prediction_feature = "http://local-ot/dataset/11306/feature/endpoint"

# kazius 3random 250, split 0.3-0.7
dataset_uri_1 = "http://local-ot/dataset/12325"
dataset_uri_2 = "http://local-ot/dataset/12326"
alg_uri = "http://local-ot/weka/RandomForest"
prediction_feature = "http://local-ot/dataset/12318/feature/endpoint"

# bbrc dataset 1000 compounds 163 fminer features, contra split 0.25-0.75
dataset_uri_2 = "http://local-ot/dataset/12557"
dataset_uri_1 = "http://local-ot/dataset/12558"
alg_uri = "http://local-ot/weka/RandomForest"
prediction_feature = "http://local-ot/dataset/12086/feature/endpoint"

dataset_uri_1 = "http://local-ot/dataset/12776"
dataset_uri_2 = "http://local-ot/dataset/12775"
alg_uri = "http://local-ot/weka/RandomForest"
prediction_feature = "http://local-ot/dataset/12689/feature/endpoint"


#randnom kazius 0.3 - 0.7 split
#dataset_uri_1 = "http://local-ot/dataset/48761"
#dataset_uri_2 = "http://local-ot/dataset/48762"
#      anti kazius 0.3 - 0.7 split      
#dataset_uri_1 = "http://local-ot/dataset/48846"
#dataset_uri_2 = "http://local-ot/dataset/48847"
#      anti kazius 0.5 - 0.5 split
#dataset_uri_1 = "http://local-ot/dataset/48874"
#dataset_uri_2 = "http://local-ot/dataset/48875"

#kazius cdk 500-3,500
#      dataset_uri_1 = "http://local-ot/dataset/22034"
#      dataset_uri_2 = "http://local-ot/dataset/22035"
 
dataset1 = OpenTox::Dataset.find(dataset_uri_1)
dataset2 = OpenTox::Dataset.find(dataset_uri_2)
demo1 dataset1,dataset2,alg_uri,prediction_feature
  
 # demo2
#dataset = OpenTox::Dataset.find(dataset_uri)
#demo2 dataset
