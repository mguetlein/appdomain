require "leverage.rb"
require "app_util.rb"

module AppDomain
  
  class LeverageModel < Leverage

    def initialize(training_dataset, feature_dataset=training_dataset, features=nil )
     
      LOGGER.info "build leverage model"
       
      feature_dataset = feature_dataset
      compounds = training_dataset.compounds
      if features
        @features = features
        features.each{|f| raise "not numeric: #{f}" unless numeric?(feature_dataset,f)}
      else
        @features = feature_dataset.features.keys
        @features.delete_if do |f|
          num = AppDomain::Util.numeric?(feature_dataset,f) 
          LOGGER.warn "skipping non-numeric-feature #{f}" unless num
          !num
        end  
      end
      
      LOGGER.debug "normalize features"
      
      @normalized = NormalizedValues.new(@features,compounds,feature_dataset)
      rows = []
      compounds.each do |c|
        row = []
        @features.each do |f|
          row << @normalized.normalize(f, AppDomain::Util.val(feature_dataset,c,f))
        end
        rows << row
      end
      m = Matrix.rows(rows)
      #puts "training matrix #{m.inspect}"
      #puts m.column_size
      #puts m.row_size
      super(m)
    end
    
    def ad(test_compound, test_dataset)
          
      test_row = []
      @features.each do |f|
        test_row << @normalized.normalize(f, AppDomain::Util.val(test_dataset,test_compound,f))
      end
      m_test = Matrix.rows([test_row])  
      #puts "test matrix #{m_test.inspect}"
      lev = super(m_test)
      
      # transform into continious 0-1 values: AD >= 0.5 <=> lev <= thres
      x = (lev/self.threshold) * -1 + 1
      y = x / Math.sqrt( 1 + x**2 )
      y = y * 0.5 + 0.5 
      
      raise if inside_domain?(lev) and y < 0.5
      
      y
    end
        
  end
  
end