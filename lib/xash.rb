require 'xash/version'
require 'roconv'
require 'pp'

module XASH

    class UndefinedFunctionError < StandardError
    end

    class UndefinedLocalVariableError < StandardError
    end

    class TypeError < StandardError
    end

    class Evaluator
        class Context < Struct.new(:lambda, :lambda_args)
            def get_local_variable(name)
                idx = lambda[0].index(name)
                unless idx
                    raise UndefinedLocalVariableError, "undefined local variable `#{name}`"
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
            @context_stack = []

            @function_table = {
                'puts' => wrap_pseudo_function(['object'], '__puts'),
                'print' => wrap_pseudo_function(['object'], '__print'),
                'for' => wrap_pseudo_function(['collection', 'function'], '__for')
            }
        end

        def eval_lambda(lambda, args)
            lambda = lambda['do']
            lambda_args, *exprs = lambda

            args = [args] unless args.class == Array

            @context_stack.push(Context.new(lambda, args))

            exprs.each{|expr| eval_expr(expr) }

            @context_stack.pop
        end

        def check_args(args, *types)
            args.zip(types) do |arg, type|
               check_arg(arg, type) 
            end
            nil
        end

        def check_arg(arg, type)
            raise TypeError, "`#{arg}` is not `#{type}`" unless self.send("#{type}?", arg)
            nil
        end

        def array?(array)
            array.class == Array
        end

        def object?(object)
            object.class == Hash
        end

        def lambda?(lambda)
            lambda.to_a[0][0] == 'do'
        end

        def collection?(collection)
            collection.class == Range or collection.class == String or collection.respond_to? :to_a
        end

        def to_collection(collection)
            case collection
            when Range
                [*collection]
            when String
                collection.each_char.to_a
            else
                raise TypeError, "`#{collection}` is not collection" unless collection? collection
                collection.to_a
            end
        end

        def eval_expr(expr)
            case expr
            when Array
                expr.map{ |e| eval_expr(e) }
            when Hash
                k, v = expr.to_a[0]

                no_eval = %w(do object)

                k = eval_expr(k)
                unless no_eval.index(k)
                    v = eval_expr(v)
                end

                case k
                #pseudo functions
                when '__puts'
                    puts v
                when '__print'
                    print v.join
                when '__for'
                    check_args(v, :collection, :lambda)

                    collection, lambda = v[0], v[1]

                    collection = to_collection(collection)

                    collection.each do |e|
                        eval_lambda(lambda, e)
                    end

                #literals
                when 'array'
                    check_arg(v, :array)
                    v
                when 'object'
                    check_arg(v, :object)
                    v
                when 'do' #lambda
                    expr #for lazy evaluation

                #function call
                when ->(k) { k.class == Hash and lambda?(k) } #lambda call
                    eval_lambda(k, v)
                else #others
                    unless @function_table.key? k
                        raise UndefinedFunctionError, "called undefiend function `#{k}`"
                    end
                    eval_lambda(@function_table[k], v)
                end
            when ->(expr){ expr.class == String and expr =~ /\$(\w+)/ }
                #local variables
                var_name = $1
                @context_stack.last.get_local_variable(var_name)
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
