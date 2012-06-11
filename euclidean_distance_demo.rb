require "rubygems"
require "opentox-ruby"
require "euclidean_distance.rb"

def self.demo1(dataset1, dataset2)
  #features = dataset1.features.keys[0..9]
  features = dataset1.features.keys #[0..4]
  alg = AppDomain::EuclideanDistance.new(dataset1, dataset1, features)
  
  puts "ad demo - merge datasets ..."
  
  data = OpenTox::Dataset.create
  featureD = "http://dataset"
  data.add_feature(featureD)
  
  [dataset1, dataset2].each do |d|
    d.compounds.each{|c| data.add_compound(c)}
    i = 0
    features.each do |f,m|
      puts "ad demo - features #{i}/#{features.size}"
      i += 1
      data.add_feature(f,m)
      d.compounds.each do |c|
        d.data_entries[c][f].each do |v|
          data.add(c,f,v)
        end if d.data_entries[c][f]
      end
    end
    d.compounds.each do |c|
      data.add(c,featureD,d==dataset1 ? "dataset1" : "dataset2")
    end
  end
  
  puts "ad demo - merge datasets ... done"

  feature = "http://ad-feature"
  data.add_feature(feature)
  dataset2.compounds.each do |c|
    ad = alg.ad(c, dataset2)
    data.add(c,feature,ad)
  end
  
  data.save
  data
  puts data.uri
  
  filename = "/tmp/data#{data.uri.split("/")[-1]}.csv"
  File.open(filename, 'w') {|f| f.write(data.to_csv) }
  puts filename
end

def self.demo2(dataset)
  features = dataset.features.keys[0..4]
  compounds = dataset.compounds #[0..99]
  
  data = OpenTox::Dataset.create
  compounds.each{|c| data.add_compound(c)}
  features.each do |f|
    data.add_feature(f,dataset.features[f])
    compounds.each do |c|
      dataset.data_entries[c][f].each do |v|
        data.add(c,f,v)
      end if dataset.data_entries[c][f]
    end
  end
  feature = "http://ad-feature"
  data.add_feature(feature)
  
  compounds.each do |c|
    tmpDataset = OpenTox::Dataset.new
    compounds.each do |c2|
      tmpDataset.add_compound(c2) if c!=c2
    end
    alg = AppDomain::EuclideanDistance.new(tmpDataset, dataset, features)
    ad = alg.ad(c, dataset)
    data.add(c,feature,ad)
  end
  
  data.save
  data
  puts data.uri
  
  filename = "/tmp/data#{data.uri.split("/")[-1]}.csv"
  File.open(filename, 'w') {|f| f.write(data.to_csv) }
  puts filename
end

#dataset_uri = "http://local-ot/dataset/1623"#kazius 250 ob
#      res = OpenTox::RestClientWrapper.post("http://local-ot/validation/plain_training_test_split",
#        {:dataset_uri=>dataset_uri,:split_ratio=>0.5,:stratified=>"anti"})
#      puts res
#      exit

#randnom kazius 0.3 - 0.7 split
#dataset_uri_1 = "http://local-ot/dataset/48761"
#dataset_uri_2 = "http://local-ot/dataset/48762"
#      anti kazius 0.3 - 0.7 split      
#dataset_uri_1 = "http://local-ot/dataset/48846"
#dataset_uri_2 = "http://local-ot/dataset/48847"
#      anti kazius 0.5 - 0.5 split
dataset_uri_1 = "http://local-ot/dataset/48874"
dataset_uri_2 = "http://local-ot/dataset/48875"

#kazius cdk 500-3,500
#      dataset_uri_1 = "http://local-ot/dataset/22034"
#      dataset_uri_2 = "http://local-ot/dataset/22035"
 
dataset1 = OpenTox::Dataset.find(dataset_uri_1)
dataset2 = OpenTox::Dataset.find(dataset_uri_2)

demo1 dataset1,dataset2
  
  #demo2
#dataset = OpenTox::Dataset.find(dataset_uri)
#demo2 dataset
