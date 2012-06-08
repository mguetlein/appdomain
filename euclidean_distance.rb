class Array
  def median #array has to be sorted!     
    (self[size/2] + self[(size+1)/2]) / 2.0
  end 
  
  def pct_rank(v)
    if (self[0]>=v)
      return 1;
    elsif (self[-1]<=v)
      return 0;
    else
      first = nil
      last = nil
      size.times do |i|
        break if (first!=nil and last!=nil)
        first = i if first==nil && self[i]>=v
        last = size-(i+1) if last==nil && self[size-(i+1)]<=v
      end
      #puts "f "+first.to_s
      #puts "l "+last.to_s
      return 1 - ((first+last)/2.0) / size.to_f
    end
  end  
  
  def mean
    self.inject{ |sum, el| sum + el }.to_f / self.size
  end
end

module AppDomain
  
  class EuclideanDistance
    
    def normalize(feature,val)
      raise if @min[feature]==nil && @delta[feature]==nil
      if @delta[feature]==0
        if val==@min
          v = 0.0
        else
          v = 1.0
        end
      else  
        v = (val-@min[feature])/@delta[feature]
      end
      raise "nan val: #{val}, min: #{@min[feature]}, delta: #{@delta[feature]}" if (v.nan?)
      v
    end
    
    def dist(c1, c2)
      d = 0
      @features.each do |f|
        raise if @values[c1][f]==nil && @values[c2][f]==nil 
        d += (@values[c1][f] - @values[c2][f])**2
      end
      d = Math.sqrt(d)
      d = d / @features.size
      d
    end
    
    def val(d,c,f,missing_value=nil)
      return 0 if d.data_entries[c]==nil || d.data_entries[c][f]==nil
#      raise "get val #{d.uri} #{c} #{f}"
      v = d.data_entries[c][f]
      if v==nil
        return nil
      elsif v.is_a?(Array)
        if v.size==0
          return nil
        else
          return v.mean
        end
      end
      raise v.to_s
    end
    
    def initialize(training_dataset, feature_dataset=training_dataset, features=nil)
      
      @feature_dataset = feature_dataset
      @compounds = training_dataset.compounds
      if features
        @features = features
      else
        @features = @feature_dataset.features.keys
      end
      LOGGER.debug "init AD - #compunds #{@compounds.size}, #features #{@features.size}"
      
      @min = {}
      @delta = {}
      @features.each do |f|
        min = Float::MAX
        max = -Float::MAX
        @compounds.each do |c|
          min = [min,val(@feature_dataset,c,f)].min
          max = [max,val(@feature_dataset,c,f)].max
        end
        @min[f] = min
        @delta[f] = max-min
      end
      
      @values = {}
      @compounds.each do |c|
        @values[c] = {}
        @features.each do |f|
          @values[c][f] = normalize(f,val(@feature_dataset,c,f))
        end
      end
      
      @center_compound = "http://center_compound"
      @values[@center_compound] = {}
      @features.each do |f|
        vals = []
        @compounds.each do |c|
          vals << @values[c][f]
        end  
        vals.sort!
        @values[@center_compound][f] = vals.median
      end
      
      #puts @values.to_yaml
      
      @sorted_distances = []
      #@compounds.size.times do |i|
      #  (0..(i-1)).each do |j|
      #    @sorted_distances << dist(@compounds[i],@compounds[j])
      #  end
      #end
      @compounds.each do |c|
        @sorted_distances << dist(@center_compound,c)
      end
      @sorted_distances.sort!
      @median = @sorted_distances.median
    end
    
    def ad(test_compound, test_dataset)
      @values[test_compound] = {}
      @features.each do |f|
        @values[test_compound][f] = normalize(f,val(test_dataset,test_compound,f))
      end
      #distances = []
      #@compounds.each do |c|
      #  distances << dist(test_compound,c)
      #end
      #distances.sort!
      #dist = distances.median
      dist = dist(test_compound,@center_compound)

      #if dist<=@median
      #  ad = 1
      #elsif dist>=3*@median
      #  ad = 0
      #else
      #  ad = 1-((dist-@median)/(2*@median))
      #end
      
      ad = EuclideanDistance.compute_ad(@median, dist)
      
      ##puts "train eucl distances #{@sorted_distances}"
      puts "this distance #{dist}"
      #ad = @sorted_distances.pct_rank(dist)
      puts "AD -> #{ad}"
      return ad 
    end
    
    private
    def self.compute_ad( train, test, point5_multiplier=3 )
      x = test/train.to_f*-1+point5_multiplier
      x/Math.sqrt(1+x**2)*0.5+0.5  
    end
        
    public
    def self.demo1(dataset1, dataset2)
      #features = dataset1.features.keys[0..9]
      features = dataset1.features.keys[0..4]
      alg = EuclideanDistance.new(dataset1, dataset1, features)
      
      data = OpenTox::Dataset.create
      featureD = "http://dataset"
      data.add_feature(featureD)
      
      [dataset1, dataset2].each do |d|
        d.compounds.each{|c| data.add_compound(c)}
        features.each do |f,m|
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
        alg = EuclideanDistance.new(tmpDataset, dataset, features)
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
    
    def self.demo
      
      dataset_uri = "http://local-ot/dataset/1623"#kazius 250 ob
#      res = OpenTox::RestClientWrapper.post("http://local-ot/validation/plain_training_test_split",
#        {:dataset_uri=>dataset_uri,:split_ratio=>0.5,:stratified=>"anti"})
#      puts res
#      exit
      
      #randnom kazius 0.3 - 0.7 split
      dataset_uri_1 = "http://local-ot/dataset/48761"
      dataset_uri_2 = "http://local-ot/dataset/48762"
      #      anti kazius 0.3 - 0.7 split      
      #dataset_uri_1 = "http://local-ot/dataset/48846"
      #dataset_uri_2 = "http://local-ot/dataset/48847"
      #      anti kazius 0.5 - 0.5 split
      #dataset_uri_1 = "http://local-ot/dataset/48874"
      #dataset_uri_2 = "http://local-ot/dataset/48875"
     
      dataset1 = OpenTox::Dataset.find(dataset_uri_1)
      dataset2 = OpenTox::Dataset.find(dataset_uri_2)
      demo1 dataset1,dataset2
      
      #demo2
      #dataset = OpenTox::Dataset.find(dataset_uri)
      #demo2 dataset
    end

  end
end


