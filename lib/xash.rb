require "xash/version"
require 'roconv'
require 'pp'

module XASH
    extend self

    def eval_lambda(lambda, *args)
        lambda_args, *exprs = lambda['do']
        exprs.each{|expr| eval_expr(expr) }
    end

    def eval_expr(expr)
        case expr
        when Array
            expr.each{ |e| eval_expr(e) }
        when Hash
            k, v = expr.to_a[0]
            case k
            when 'puts'
                v = eval_expr(v)
                puts v
            #pseudo functions
            when 'for'
                #check_arg(v, 2) or check_arg(v, :collection, :lambda)
                v = eval_expr(v)
                collection, func = v[0], v[1]
                #only range
                collection = [*collection]

                collection.each do |e|
                    eval_lambda(func, e)
                end
            when 'do'
                expr
            else
                puts "#{k} called!"
            end
        else #primitives
            expr
        end
    end

    def eval(code)
        code = Roconv.convert(code)
        pp code
        eval_expr(code)
    end
end
