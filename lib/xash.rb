require 'xash/version'
require 'xash/evaluator'

module XASH
    def self.eval(code)
        e = Evaluator.new
        e.eval(code)
    end
end
