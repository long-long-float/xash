require "xash/version"
require 'roconv'

module XASH
    extend self

    def eval(code)
        code = Roconv.convert(code)

        code.each do |expr|
            case expr
            when Hash
                case expr.size
                when 1
                    #function call
                    expr = expr.to_a
                    func_name, arg = expr[0]
                    case func_name
                    when 'puts'
                        puts arg
                    end
                end
            end
        end
    end
end
