module AppDomain
  
  class NormalizedValues
    
    def initialize(features,compounds,dataset)
      @min = {}
      @delta = {}
      features.each do |f|
        min = Float::MAX
        max = -Float::MAX
        compounds.each do |c|
          min = [min,Util.val(dataset,c,f)].min
          max = [max,Util.val(dataset,c,f)].max
        end
        @min[f] = min
        @delta[f] = max-min
      end
    end
    
    def normalize(feature,val)
      raise if @min[feature]==nil && @delta[feature]==nil
      if @delta[feature]==0
        if val==@min[feature]
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
    
  end
  
  module Util
    
    def self.numeric?(d,f)
      return true if f=~/\/feature\/bbrc\// 
      type = d.features[f][RDF.type]
      raise "feature #{f} has no type #{d.features[f].inspect}" unless type
      type.to_a.flatten.include?(OT.NumericFeature) 
    end
    
    def self.val(d,c,f,missing_value=nil)
      return 0 if d.data_entries[c]==nil || d.data_entries[c][f]==nil
    #      raise "get val #{d.uri} #{c} #{f}"
      v = d.data_entries[c][f]
      if v==nil
        return nil
      elsif v.is_a?(Array)
        if v.size==0
          return nil
        else
          return v.to_scale.mean
        end
      end
      raise v.to_s
    end

  end
end