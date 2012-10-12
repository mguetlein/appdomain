require "matrix"

module AppDomain
  
  class Leverage
    
    attr_reader :threshold
    
    def initialize(m)
      
      LOGGER.debug "build leverage model according to matrix"
      @threshold = 3 * ( m.column_size + 1 ) / (m.row_size.to_f)
      #puts @threshold
      x = m
      xt = x.transpose
      begin
        @xtx1 = ( xt * x ).inverse
      rescue ExceptionForMatrix::ErrNotRegular => ex
        $stderr.puts "data matrix X"
        $stderr.puts x
        $stderr.puts "not regular: XTX"
        $stderr.puts( xt * x )
        raise ex
      end
      #@hat = ( x * @xtx1 ) * xt
      
    end
  
    def ad(v)
      return nil unless @xtx1
      raise unless v.row_size == 1
      
      vt = v.transpose
      h = (v * @xtx1) * vt;
      h[0,0]
      #lev = [];
      #v.row_size.times do |i|
      #  lev[i] = h[i,i]
      #end
    end
    
    def inside_domain?(ad)
      return ad < threshold
    end
        
  end
  
  
end  

#feats = 30
#instances = 50
#feats_mean = feats.times.collect{|x| rand}
#feats_stdev = feats.times.collect{|x| rand}
#  
#rows = []
#instances.times do |i|
#  row = []
#  feats.times do |f|
#    val = feats_mean[f] + feats_stdev[f] * rand * (rand < 0.5 ? 1 : -1) 
#    row << val
#  end
# # puts row.inspect
#  rows << row
#end
#
#m = Matrix.rows(rows)  
#
##puts m.inspect
##puts m.row_size
##puts m.column_size
#
##m = Matrix[[1,2,3,4,5,6,7], [1,2,3,4,5,6,7], [[1,2,3,4,5,6,7]]]
#
#lev = AppDomain::Leverage.new(m)
#puts "threshold: "+lev.threshold.to_s
#
#test = []
#feats.times do |f|
#  test << feats_mean[f] + feats_stdev[f] * rand * (rand < 0.5 ? 1 : -1) 
#end
#m_test = Matrix.rows([test])  
#ad = lev.ad(m_test)
#puts ad
#puts lev.inside_domain?(ad)
#
#test = []
#feats.times do |f|
#  test << feats_mean[f] + feats_stdev[f] * rand * (rand < 0.5 ? 1 : -1) 
#end
#m_test = Matrix.rows([test])  
#ad = lev.ad(m_test)
#puts ad
#puts lev.inside_domain?(ad)
