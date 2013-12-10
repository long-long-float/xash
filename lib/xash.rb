require 'xash/version'
require 'roconv'
require 'pp'
require 'yaml'

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

        def error(klass, msg)
            cc = @context_stack.current
            raise klass, <<-EOS
variables : #{cc.local_variables.to_yaml}
lambda body : #{cc.lambda_body}
#{@context_stack.current} : #{msg}
            EOS
        end

        class Context
            attr_reader :lambda_body

            def initialize(lambda, lambda_args)
                @variable_table = {}
                lambda_args = lambda_args.dup
                lambda[0].each do |arg|
                    @variable_table[arg] = lambda_args.shift
                end

                @lambda_body = lambda[1]
            end

            def attach(lambda, lambda_args)
                @attached_table = {}
                lambda_args = lambda_args.dup
                lambda[0].each do |arg|
                    @attached_table[arg] = lambda_args.shift
                end

                ret = yield

                @attached_table = nil

                ret
            end

            def defined_local_variable?(name)
                @variable_table.include?(name) || @attached_table && @attached_table.include?(name)
            end

            def local_variable(name)
                @variable_table[name] || @attached_table && @attached_table[name]
            end

            def local_variables
                @variable_table.merge(@attached_table || {})
            end

            def set_local_variable(name, val)
                if @variable_table.key? name
                    STDERR.puts "`#{name}` has been already assigned!"
                end
                @variable_table[name] = val
            end
        end

        class ContextStack
            def initialize(evaluator)
                @evaluator = evaluator

                @context_stack = []

                #root context
                @context_stack.push(Context.new([[]], []))
            end

            def exist_local_variable?(name)
                @context_stack.reverse_each do |context|
                    if context.defined_local_variable?(name)
                        return true
                    end
                end
                false
            end

            def local_variable(name)
                @context_stack.reverse_each do |context|
                    if context.defined_local_variable?(name)
                        return context.local_variable(name)
                    end
                end
                @evaluator.error UndefinedLocalVariableError, "undefined local variable `#{name}`"
            end

            def local_variables
                @context_stack.last.local_variables
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

            def attach(lambda, lambda_args)
                @context_stack.last.attach(lambda, lambda_args) do
                    yield(self)
                end
            end

            def meta_context
                current = @context_stack.pop
                ret = yield
                @context_stack.push(current)
                ret
            end

            def current
                @context_stack.last.dup
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
            @context_stack = ContextStack.new(self)

            {
                'for' => wrap_pseudo_function(['collection', 'lambda'], '__for'),
                # define function
                'def' => wrap_pseudo_function(['function_name', 'lambda'], '__def'),
                'alias' => wrap_pseudo_function(['old', 'new'], '__alias'),
                'meta_context' => wrap_pseudo_function(%w(lambda_args lambda), '__meta_context'),
                'local_variables' => wrap_pseudo_function([], '__local_variables'),
                #literals
                #'array' => wrap_pseudo_function([], '__array'),
                'object' => wrap_pseudo_function(['obj'], '__object'),
                'range' => wrap_pseudo_function(['a', 'b'], '__range'),
            }.each do |name, val|
                @context_stack.set_local_variable(name, val)
            end

            #とりあえず

            #eval(YAML.load_file("#{File::dirname(__FILE__)}/kernel.yml"))
        end

        def eval_lambda(lambda, args)
            lambda = lambda['do']
            lambda_args, *exprs = lambda

            ret = nil
            exprs.each do |expr|
                ret = eval_expr(expr)
                if c.exist_local_variable?('next_value')
                    ret = c.local_variable('next_value')
                    break
                end
            end
            ret
        end

        def push_context(lambda, args)
            @context_stack.context(lambda['do'], args) do |c|
                c.set_local_variable('it', args[0])
                c.set_local_variable('args', args)

                eval_lambda(lambda, args)
            end
        end

        def attach_context(lambda, args)
            @context_stack.attach(lambda['do'], args) do |c|
                eval_lambda(lambda, args)
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
            error TypeError, "`#{arg}` is not `#{type}`" unless self.send("#{type}?", arg)
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
                error TypeError, "`#{collection}` is not collection" unless collection? collection
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
                    check_args(v, :array, :lambda)

                    args, lambda = v

                    #current
                    @context_stack.meta_context do
                        #meta_context lambda
                        @context_stack.meta_context do
                            #meta context
                            attach_context(lambda, args)
                        end
                    end
                when '__next'
                    ret_val = v[0]

                    @context_stack.next(ret_val)

                    ret_val
                when '__local_variables'
                    @context_stack.local_variables
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
            when ->(expr){ expr.is_a? String and expr =~ /\$(\w+)/ }
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