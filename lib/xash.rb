require 'xash/version'
require 'xash/evaluator'

require 'roconv'

module XASH
    def self.eval(code)
        e = Evaluator.new
        e.eval(Roconv.convert(code))
    end
end
