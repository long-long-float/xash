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

    class InvalidContextIDError < StandardError
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

            def context(lambda, lambda_args)
                @context_stack.push(Context.new(lambda, lambda_args))
                ret = yield(self)
                @context_stack.pop
                ret
            end

            def meta_context
                current = @context_stack.pop
                ret = yield
                @context_stack.push(current)
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

            {
                'for' => wrap_pseudo_function(['collection', 'lambda'], '__for'),
                # define function
                'def' => wrap_pseudo_function(['function_name', 'lambda'], '__def'),
                'alias' => wrap_pseudo_function(['old', 'new'], '__alias'),
                'meta_context' => wrap_pseudo_function(%w(context_id lambda), '__meta_context'),
                #literals
                #'array' => wrap_pseudo_function([], '__array'),
                'object' => wrap_pseudo_function(['obj'], '__object'),
                'range' => wrap_pseudo_function(['a', 'b'], '__range'),
            }.each do |name, val|
                @context_stack.set_local_variable(name, val)
            end

            #とりあえず

            eval(YAML.load_file("#{File::dirname(__FILE__)}/kernel.yml"))
        end

        def eval_lambda(lambda, args)
            lambda = lambda['do']
            lambda_args, *exprs = lambda

            @context_stack.context(lambda, args) do |c|
                c.set_local_variable('it', args[0])
                c.set_local_variable('args', args)

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
            lambda.is_a? Hash and lambda.to_a[0][0] == 'do'
        end

        def string?(string)
            string.class == String
        end

        def integer?(integer)
            integer.class == Fixnum
        end

        def collection?(collection)
            collection.is_a? Range or collection.is_a? String or collection.respond_to? :to_a
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
                    print v.join
                when '__for'
                    check_args(v, :collection, :lambda)

                    collection, lambda = v

                    collection = to_collection(collection)

                    collection.map do |e|
                        eval_lambda(lambda, [e])
                    end
                when '__def'
                    check_args(v, :string)

                    name, lambda = v

                    @context_stack.assign(name, lambda)
                when '__alias'
                    check_args(v, :string, :string)

                    old, new = v

                    @context_stack.assign(new, @context_stack.local_variable(old).dup)
                when '__meta_context'
                    check_args(v, :lambda)

                    lambda = v[0]

                    #current
                    @context_stack.meta_context do
                        #meta_context lambda
                        @context_stack.meta_context do
                            #meta context
                            eval_lambda(lambda, [])
                        end
                    end
                when '__object'
                    check_args(v, :object)
                    puts "__object => #{v[0]}"
                    v[0]
                when '__range'
                    Range.new(v[0], v[1])

                when 'do' #lambda
                    expr #for lazy evaluation

                #function call
                when ->(k) { lambda?(k) } #lambda call
                    eval_lambda(k, v)
                else #others
                    eval_lambda(@context_stack.local_variable(k), v)
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