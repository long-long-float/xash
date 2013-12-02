require "xash/version"
require 'roconv'
require 'pp'

module XASH

    class Evaluator
        class Context < Struct.new(:lambda, :lambda_args)
            def get_local_variable(name)
                idx = lambda[0].index(name)
                unless idx
                    #TODO raise exception
                end
                lambda_args[idx]
            end
        end

        def initialize
            @context = nil
        end

        def eval_lambda(lambda, *args)
            lambda = lambda['do']
            lambda_args, *exprs = lambda

            @context = Context.new(lambda, args)

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
            when ->(expr){ expr.class == String and expr =~ /\$(\w)+/ }
                #local variables
                var_name = $1
                @context.get_local_variable(var_name)
            else
                #primitives
                expr
            end
        end

        def eval(code)
            code = Roconv.convert(code)
            pp code
            eval_expr(code)
        end
    end

    def self.eval(code)
        e = Evaluator.new
        e.eval(code)
    end
end
