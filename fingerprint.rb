
class Object
  def deep_copy()
    Marshal.load(Marshal.dump(self))
  end
end

class Array
   def sum
      inject( 0 ) { |sum,x| sum+x }
   end
   def sum_square
      inject( 0 ) { |sum,x| sum+x*x }
   end
   def *(other) # dot_product
      ret = []
      return nil if !other.is_a? Array || size != other.size
      self.each_with_index {|x, i| ret << x * other[i]}
      ret.sum
   end
end

module AppDomain
  
  class FingerprintModel
    
    def initialize(training_dataset, feature_dataset=training_dataset, features=nil, params={}, feature_weights=nil)

      @method = "consensus"
      @consensus_pct = 10
      @num_neighbors = 5
      @inflection_point = 2
      
      params.each do |key,v|
        k = key.to_s
        case k
        when "method"
          @method = v.to_s
        when "consensus_pct"
          @consensus_pct = v.to_i
        when "num_neighbors"
          @num_neighbors = v.to_i
        when "inflection_point"
          @inflection_point = v.to_f
        end 
      end
          
      feature_dataset = feature_dataset
      @compounds = training_dataset.compounds
      if features
        @features = features.deep_copy
        features.each{|f| raise "not bbrc #{f}" unless f=~/\/feature\/bbrc\//}
      else
        @features = feature_dataset.features.keys
        @features.delete_if do |f|
          if !(f=~/\/feature\/bbrc\//) 
            LOGGER.warn "skipping non-bbrc-feature #{f}"
            true
          else
            false
          end
        end  
      end
      
      weight_less = 0
      if feature_weights
        @weight_array = []
        @features.delete_if do |f|
          no_weight = (feature_weights[f]==nil || feature_weights[f]==0)
          LOGGER.debug "remove weightless feature #{f}" if no_weight
          if no_weight
            weight_less += 1
          else
            @weight_array << feature_weights[f]
          end
          no_weight
        end
      else
        @weight_array = Array.new(@features.size,1)
      end
      @feature_weights = feature_weights
      LOGGER.debug "init AD - #compunds #{@compounds.size}, #features #{@features.size}"
      if feature_weights
        LOGGER.debug "init AD - #{weight_less}/#{weight_less+@features.size} weightless features have been removed"
        LOGGER.debug "init AD - feature_weights: "+@feature_weights.values.delete_if{|w| w==nil or w==0}.sort{|a,b| b<=>a}[0..30].inspect+
          (@feature_weights.values.size>31 ? " ..." : "")
      end
      LOGGER.debug "init AD - weight-array: "+@weight_array[0..30].inspect+(@weight_array.size>31 ? " ..." : "")
      
      LOGGER.debug "init AD - #compunds #{@compounds.size}, #features #{@features.size}"

      @fingerprints = []
      card = []
      @compounds.each do |c|
        @fingerprints << fingerprint(c,feature_dataset)
        card << @fingerprints[-1].sum
      end
      LOGGER.debug "init AD - fingerprint cardinalities "+card[0..30].inspect+(card.size>31 ? " ..." : "")
      LOGGER.debug "init AD - fingerprint cardinality median "+card.to_scale.median.to_s
      
      if @method=="consensus"
        
        @consensus_fp = []
        @features.size.times do |i|
          min_num = @fingerprints.size*1/@consensus_pct
          count = 0
          @fingerprints.each do |fp|
            count+=1 if fp[i]==1
            break if count>=min_num
          end
          @consensus_fp << ((count>=min_num) ? 1 : 0)
        end
        
        LOGGER.debug "init AD - consensus fingerprint "+@consensus_fp[0..30].inspect+(@consensus_fp.size>31 ? " ..." : "")
        LOGGER.debug "init AD - consensus fingerprint cardinality "+@consensus_fp.sum.to_s
        
        tanimotos = []
        @fingerprints.each do |fp|
          tanimotos << tanimoto_distance(fp,@consensus_fp)
        end
        @fingerprints = nil
        
        @threshold = tanimotos.to_scale.median
        @threshold = (tanimotos - [0, 0.0]).min if @threshold==0
        
      elsif @method=="knn"
        
        LOGGER.debug "init AD - compute distance matrix"
        distance_hash = {}  
        @fingerprints.size.times do |i|
          (0..(i-1)).each do |j|
            distance_hash[[j,i]] = tanimoto_distance(@fingerprints[i],@fingerprints[j])
          end
        end
        LOGGER.debug "init AD - compute knn distance"
        knn_distances = []
        @fingerprints.size.times do |i|
          distances = []
          @fingerprints.size.times do |j|
            next if i==j
            distances << distance_hash[[i,j].sort] 
          end
          #LOGGER.debug "init AD - distances #{distances.sort.inspect}"
          distances = distances.sort[0..(@num_neighbors-1)]
          knn_distances << distances.to_scale.median
          #LOGGER.debug "init AD - knn-median #{distances.to_scale.median}"
        end
        @threshold = knn_distances.to_scale.median
        @threshold = (knn_distances - [0, 0.0]).min if @threshold==0
      
      else
        raise "wtf method"
      end
      LOGGER.debug "init AD - threshold #{@threshold}"
      #$stderr.flush
      #puts "consensus fp: #{@consensus_fp.inspect}\n"
      #puts tanimotos.sort.inspect+"\n"
      #$stdout.flush
    end
    
    def ad(test_compound, dataset)
      
      fp_test = fingerprint(test_compound,dataset)
      if @method=="consensus"
        tanimoto = tanimoto_distance(fp_test, @consensus_fp)
      else
        tanimotos = []
        @fingerprints.each do |fp|
          tanimotos << tanimoto_distance(fp_test, fp)
        end
        tanimotos = tanimotos.sort[0..(@num_neighbors-1)]
        tanimoto = tanimotos.to_scale.median
      end
      
      x = (tanimoto/@threshold) * -1 + @inflection_point
      y = x / Math.sqrt( 1 + x**2 )
      y = y * 0.5 + 0.5
      
      raise if y<0.5 && tanimoto<@threshold
       
      y
    end
    
    def tanimoto_old(fp1,fp2)
      dot = fp1 * fp2
      den = fp1.sum_square + fp2.sum_square - dot
      dot.to_f/den.to_f
    end
    
    def tanimoto_distance(fp1,fp2)
      and_ = 0; or_ = 0
      fp1.size.times do |i|
        if fp1[i]==1
          and_ += @weight_array[i] if fp2[i]==1
          or_ += @weight_array[i] 
        elsif fp2[i]==1
          or_ += @weight_array[i]
        end
      end
      #puts "and "+and_.to_s
      #puts "or "+or_.to_s
      if and_==0
        1
      else
        1 - (and_ / or_.to_f)
      end
    end
    
    def fingerprint(c,d)
      fp=[]
      @features.each do |f|
        fp << ((d.data_entries[c] and d.data_entries[c][f] and d.data_entries[c][f][0]==1) ? 1 : 0)
      end
#      puts fp.inspect
      fp
    end
  end
end

#fp1 = [1,0,0,1,1,1,0,1,1,1]
#fp2 = [1,0,1,1,0,1,0,1,1,1]
#dot = fp1 * fp2
#puts dot
#den = fp1.sum_square + fp2.sum_square - dot
#puts den
#tan = dot.to_f/den.to_f
#puts tan
#puts ""
#
#def tan2(fp1,fp2)
#  and_ = 0; or_ = 0
#  fp1.size.times do |i|
#    if fp1[i]==1
#      and_ += 1 if fp2[i]==1
#      or_ += 1 
#    elsif fp2[i]==1
#      or_ += 1
#    end
#  end
#  puts "and "+and_.to_s
#  puts "or "+or_.to_s
#  and_ / or_.to_f
#end
#puts tan2(fp1,fp2)


#
#num = 500
#size = 250
#avg_cardinality = 10
#fps = []
#cards = [] 
#num.times do 
#  fp = Array.new(size,0)
#  card = avg_cardinality
#  mod = 0.9 + (0.2 * rand) # 0.9 - 1.1
#  card *= mod
#  card.round.to_i.times do 
#    fp[rand(size)] = 1
#  end
#  fps << fp
#  cards << fp.sum
#end  

#require "rubygems"
#require "statsample"
#
#puts cards.inspect
#puts cards.to_scale.median
#
#fp_count = []
#size.times do |i|
#  count = 0
#  num.times do |fp|
#    count+=1 if fps[fp][i]==1
#  end
#  fp_count << count
#end
#puts fp_count.inspect
#puts fp_count.sum
#
#
#
#consensus_fp = []
#size.times do |i|
#  min_num = num*1/10.0
#  count = 0
#  num.times do |fp|
#    count+=1 if fps[fp][i]==1
#    break if count>=min_num
#  end
#  consensus_fp << ((count>=min_num) ? 1 : 0)
#end
#puts consensus_fp.inspect
#puts consensus_fp.sum

#puts AppDomain::FingerprintModel.tanimoto(fp1,fp2)