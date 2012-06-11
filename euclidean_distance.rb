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
    
    def dist(c1, c2, values_c1, values_c2)
      d = 0
      @features.each do |f|
        raise if values_c1[c1][f]==nil && values_c2[c2][f]==nil 
        d += (values_c1[c1][f] - values_c2[c2][f])**2
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
      
      feature_dataset = feature_dataset
      compounds = training_dataset.compounds
      if features
        @features = features
      else
        @features = feature_dataset.features.keys
      end
      LOGGER.debug "init AD - #compunds #{compounds.size}, #features #{@features.size}"
      
      LOGGER.debug "init AD - normalize features"
      
      @min = {}
      @delta = {}
      @features.each do |f|
        min = Float::MAX
        max = -Float::MAX
        compounds.each do |c|
          min = [min,val(feature_dataset,c,f)].min
          max = [max,val(feature_dataset,c,f)].max
        end
        @min[f] = min
        @delta[f] = max-min
      end
      
      training_values = {}
      compounds.each do |c|
        training_values[c] = {}
        @features.each do |f|
          training_values[c][f] = normalize(f,val(feature_dataset,c,f))
        end
      end
      
      LOGGER.debug "init AD - compute center"
      
      @center_compound = "http://center_compound"
      @values = {}
      @values[@center_compound] = {}
      @features.each do |f|
        vals = []
        compounds.each do |c|
          vals << training_values[c][f]
        end  
        vals.sort!
        @values[@center_compound][f] = vals.median
      end
      
      #puts @values.to_yaml
      
      LOGGER.debug "init AD - compute distance to center"
      
      distances = []
      #@compounds.size.times do |i|
      #  (0..(i-1)).each do |j|
      #    @distances << dist(@compounds[i],@compounds[j])
      #  end
      #end
      compounds.each do |c|
        distances << dist(@center_compound,c,@values,training_values)
      end
      distances.sort!
      @median = distances.median
      
      LOGGER.debug "init AD - done (median distance to center: #{@median}"

    end
    
    def ad(test_compound, test_dataset)
      test_values = {}
      test_values[test_compound] = {}
      @features.each do |f|
        test_values[test_compound][f] = normalize(f,val(test_dataset,test_compound,f))
      end
      #distances = []
      #@compounds.each do |c|
      #  distances << dist(test_compound,c)
      #end
      #distances.sort!
      #dist = distances.median
      dist = dist(test_compound,@center_compound,test_values,@values)

      #if dist<=@median
      #  ad = 1
      #elsif dist>=3*@median
      #  ad = 0
      #else
      #  ad = 1-((dist-@median)/(2*@median))
      #end
      
      if @median==0
        if dist==0
          ad = 0.9999999999
        else
          ad = 0.0000000001
        end
      else
        ad = EuclideanDistance.compute_ad(@median, dist)
      end
      
      #LOGGER.debug "AD for #{test_compound} : #{ad}"
      
      ##puts "train eucl distances #{@sorted_distances}"
      #puts "this distance #{dist}"
      #ad = @sorted_distances.pct_rank(dist)
      #puts "AD -> #{ad}"
      return ad 
    end
    
    private
    def self.compute_ad( train, test, point5_multiplier=3 )
      x = test/train.to_f*-1+point5_multiplier
      x/Math.sqrt(1+x**2)*0.5+0.5  
    end
  end
end

