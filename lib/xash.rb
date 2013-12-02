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
                    raise "local variable #{name} not found!"
                end
                lambda_args[idx]
            end
        end

        def call_function(name, args)
            { name => args }
        end

        def make_lambda(args, *exprs)
            { 'do' => [args, *exprs] }
        end

        def wrap_pseudo_function(args, realname)
            make_lambda(args, [ call_function(realname, args.map{|arg| "$#{arg}"}) ])
        end

        def initialize
            @context = nil
            @function_table = {
                'puts' => wrap_pseudo_function(['object'], '__puts'),
                'for' => wrap_pseudo_function(['collection', 'function'], '__for')
            }
        end

        def eval_lambda(lambda, args)
            lambda = lambda['do']
            lambda_args, *exprs = lambda

            args = [args] unless args.class == Array
            @context = Context.new(lambda, args)

            exprs.each{|expr| eval_expr(expr) }
        end

        def to_collection(collection)
            case collection
            when Range
                [*collection]
            else
                collection.to_a
            end
        end

        def eval_expr(expr)
            case expr
            when Array
                expr.map{ |e| eval_expr(e) }
            when Hash
                k, v = expr.to_a[0]
                case k
                when '__puts' #pseudo functions
                    v = eval_expr(v)
                    puts v
                when '__for'
                    #check_arg(v, 2) or check_arg(v, :collection, :lambda)
                    v = eval_expr(v)
                    collection, lambda = v[0], v[1]

                    collection = to_collection(collection)

                    collection.each do |e|
                        eval_lambda(lambda, e)
                    end
                when 'do' #lambda
                    expr
                else #other functions
                    eval_lambda(@function_table[k], eval_expr(v))
                end
            when ->(expr){ expr.class == String and expr =~ /\$(\w+)/ }
                #local variables
                var_name = $1
                @context.get_local_variable(var_name).tap do |val|
                    #puts "get local variable! #{var_name} : #{val}"
                end
            else
                #primitives
                expr
            end
        end

        def eval(code)
            code = Roconv.convert(code)
            eval_expr(code)
        end
    end

    def self.eval(code)
        e = Evaluator.new
        e.eval(code)
    end
end
