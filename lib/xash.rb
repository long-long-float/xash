require "xash/version"
require 'roconv'

module XASH
    extend self

    def eval(code)
        code = Roconv.convert(code)
    end
end
