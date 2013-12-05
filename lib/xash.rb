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
        class Context
            def initialize(lambda, lambda_args)
                @variable_table = {}
                lambda_args = lambda_args.dup
                lambda[0].each do |arg|
                    @variable_table[arg] = lambda_args.shift
                end
            end

            def defined_local_variable?(name)
                @variable_table.include? name
            end

            def local_variable(name)
                @variable_table[name]
            end

            def set_local_variable(name, val)
                if @variable_table.key? name
                    STDERR.puts "`#{name}` has been already assigned!"
                end
                @variable_table[name] = val
            end
        end

        class ContextStack
            def initialize
                @context_stack = []

                #root context
                @context_stack.push(Context.new([[]], []))
            end

            def local_variable(name)
                @context_stack.reverse_each do |context|
                    if context.defined_local_variable?(name)
                        return context.local_variable(name)
                    end
                end
                raise UndefinedLocalVariableError, "undefined local variable `#{name}`"
            end

            def set_local_variable(name, val)
                @context_stack.last.set_local_variable(name, val)
            end

            def assign(name, val)
                @context_stack[-2].set_local_variable(name, val)
            end

            def scope(lambda, lambda_args)
                @context_stack.push(Context.new(lambda, lambda_args))
                ret = yield
                @context_stack.pop
                ret
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
            @context_stack = ContextStack.new

            @function_table = {
                'print' => wrap_pseudo_function(['object'], '__print'),
                'for' => wrap_pseudo_function(['collection', 'lambda'], '__for'),
                # define function
                'def' => wrap_pseudo_function(['function_name', 'lambda'], '__def'),
                'assign' => wrap_pseudo_function(['variable_name', 'value'], '__assign'),
                #literals
                'array' => wrap_pseudo_function(['ary'], '__ary'),
                'object' => wrap_pseudo_function(['obj'], '__object'),
                'range' => wrap_pseudo_function(['a', 'b'], '__range'),
            }

            #とりあえず

            eval(YAML.load_file("#{File::dirname(__FILE__)}/kernel.yml"))
        end

        def eval_lambda(lambda, args)
            lambda = lambda['do']
            lambda_args, *exprs = lambda

            args = [args] unless args.class == Array

            @context_stack.scope(lambda, args) do
                ret = nil
                exprs.each{|expr| ret = eval_expr(expr) }
                ret
            end
        end

        def check_args(args, *types)
            args.zip(types) do |arg, type|
                next unless type
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

        def string?(string)
            string.class == String
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
                when '__print'
                    pp v
                    print v.join
                when '__for'
                    check_args(v, :collection, :lambda)

                    collection, lambda = v

                    collection = to_collection(collection)

                    collection.map do |e|
                        eval_lambda(lambda, e)
                    end
                when '__def'
                    check_args(v, :string, :lambda)

                    name, lambda = v

                    @function_table[name] = lambda
                when '__assign'
                    check_args(v, :string)

                    name, val = v

                    @context_stack.assign(name, val)
                when '__array'
                    check_arg(v, :array)
                    v
                when '__object'
                    check_arg(v, :object)
                    v
                when '__range'
                    Range.new(v[0], v[1])

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
                @context_stack.local_variable(var_name)
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
