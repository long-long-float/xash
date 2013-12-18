require 'xash/context'
require 'xash/context_stack'
require 'xash/type'

module XASH
    class Evaluator

        def error(klass, msg)
            cc = @context_stack.current
            raise klass, <<-EOS
variables : #{cc.variables.to_yaml}
lambda body : #{cc.lambda_body}
#{@context_stack.current} : #{msg}
            EOS
        end

        def warn(msg)
            STDERR.puts msg
        end

        def call_function(name, args)
            { name => args }
        end

        def make_lambda(args, exprs)
            { 'do' => [args, *exprs] }
        end

        def wrap_pseudo_function(args, realname)
            make_lambda(args, [ call_function(realname, args.map{|arg| "$#{arg}"}) ])
        end

        def import_yaml(mod_name)
            attach_context(make_lambda([], YAML.load_file(mod_name)), [])
        end

        def initialize
            @context_stack = ContextStack.new(self)

            {
                'for' => wrap_pseudo_function(['collection', 'lambda'], '__for'),
                'if' => wrap_pseudo_function(['condition', 'lambda'], '__if'),
                'case' => wrap_pseudo_function([], '__case'),
                # define function
                'def' => wrap_pseudo_function(['function_name', 'lambda'], '__def'),
                'alias' => wrap_pseudo_function(['old', 'new'], '__alias'),
                'import_yaml' => wrap_pseudo_function([], '__import_yaml'),
                'boot' => wrap_pseudo_function(['lambda'], '__boot'),

                'meta_context' => wrap_pseudo_function(%w(lambda_args lambda), '__meta_context'),
                'variables' => wrap_pseudo_function([], '__local_variables'),
                'expr' => wrap_pseudo_function([], '__expr'),
                #literals
                'object' => wrap_pseudo_function(['obj'], '__object'),
                'range' => wrap_pseudo_function(['a', 'b'], '__range'),
            }.each do |name, val|
                @context_stack.set_local_variable(name, val)
            end

            #とりあえず

            import_yaml("#{File::dirname(__FILE__)}/kernel.yml")
        end

        def eval_lambda(lambda, args, context)
            lambda = lambda['do']
            lambda_args, *exprs = lambda

            ret = nil
            exprs.each do |expr|
                ret = eval_expr(expr)
                if context.exist_local_variable?('next_value')
                    ret = context.variable('next_value')
                    break
                end
            end
            ret
        end

        def push_context(lambda, args)
            @context_stack.context(lambda, args) do |c|
                c.set_local_variable('it', args[0])
                c.set_local_variable('args', args)
                c.set_local_variable('self', lambda)

                eval_lambda(lambda, args, c)
            end
        end

        def exec(lambda, args)
            case lambda
            when ->(l){ Type.lambda? l }
                push_context(lambda, args)
            when Context
                push_context(lambda, args)
            else
                eval_expr(lambda)
            end
        end

        def attach_context(lambda, args)
            @context_stack.attach(lambda['do'], args) do |c|
                c.set_local_variable('it', args[0], false)
                c.set_local_variable('args', args, false)

                eval_lambda(lambda, args, c)
            end
        end

        def boot_context(lambda)
            Context.new(lambda['do'], [], @context_stack.current)
        end

        def check_args(args, *types)
            args.zip(types) do |arg, type|
                next unless type
                check_arg(arg, type)
            end
            nil
        end

        def check_arg(arg, type)
            error TypeError, "`#{arg}` is not `#{type}`" unless Type.send("#{type}?", arg)
            nil
        end

        OPERATORS = {
            '==' => ->(l, r){ l.eql? r },
            '/=' => ->(l, r){ !(l.eql? r) },

            '>=' => ->(l, r){ l >= r },
            '<=' => ->(l, r){ l <= r },
            '>' => ->(l, r){ l > r },
            '<' => ->(l, r){ l < r },

            'or' => ->(l, r){ l || r },
            'and' => ->(l, r){ l && r },
            'xor' => ->(l, r){ l ^ r },

            '+' => ->(l, r){ l + r },
            '-' => ->(l, r){ l - r },

            'mul' => ->(l, r){ l * r },
            'div' => ->(l, r){ l / r },
            'mod' => ->(l, r){ l % r }
        }

        #convert tokens to "Reverse Polish Notation"
        def to_rpn(tokens, rpn)
            OPERATORS.each_key do |ope|
                if idx = tokens.index(ope)
                    to_rpn(tokens[0...idx], rpn)
                    to_rpn(tokens[(idx + 1)...tokens.size], rpn)
                    rpn << ope
                    return 
                end
            end
            rpn << tokens[0]
        end

        def condition(cond)
            !(cond == false or cond == 0 or cond == nil)
        end

        def eval_expr(expr)
            case expr
            when Array
                expr.map{ |e| eval_expr(e) }
            when Hash
                k, v = expr.to_a[0]

                no_eval = %w(do object if for)

                k = eval_expr(k)
                unless no_eval.index(k)
                    v = eval_expr(v)
                end

                case k
                #pseudo functions
                when '__print'
                    print v.join
                when '__for'
                    check_args(v, :collection)

                    collection, lambda = v

                    collection = Type.to_collection(collection)

                    collection.map do |e|
                        exec(lambda, [e])
                    end
                when '__if'
                    check_args(v, :array)

                    condition, lambda = v
                    condition = eval_expr(call_function('expr', condition))

                    if condition(condition)
                        exec(lambda, [])
                    else
                        nil
                    end

                when '__case'
                    args = @context_stack.variable('args')

                    #0 2 4 ...
                    0.step(args.size, 2).map do |i|
                        unless Type.lambda?(args[i])
                            if condition(eval_expr(call_function('expr', args[i])))
                                break exec(args[i + 1], [])
                            end
                        else
                            exec(args[i], [])
                        end
                    end

                when '__def'
                    check_args(v, :string)

                    name, lambda = v

                    @context_stack.assign(name, lambda)
                when '__alias'
                    check_args(v, :string, :string)

                    old, new = v

                    @context_stack.assign(new, @context_stack.variable(old).dup)
                when '__import_yaml'
                    modules = @context_stack.variable('args')

                    @context_stack.meta_context do
                        modules.each do |mod|
                            import_yaml(mod)
                        end
                    end

                    nil

                when '__boot'
                    check_args(v, :lambda)

                    lambda = v[0]

                    boot_context(lambda)

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
                    @context_stack.variables
                when '__expr'
                    
                    tokens = @context_stack.variable('args')

                    rpn = []
                    to_rpn(tokens, rpn)

                    stack = []
                    rpn.each do |token|
                        stack << if OPERATORS.key? token
                                r, l = stack.pop, stack.pop
                                OPERATORS[token][l, r]
                            else
                                token
                            end
                    end

                    stack[0]

                when '__object'
                    check_args(v, :object)
                    puts "__object => #{v[0]}"
                    v[0]
                when '__range'
                    Range.new(v[0], v[1])

                when 'do' #lambda
                    expr #for lazy evaluation

                #function call
                when ->(k) { Type.lambda?(k) } #lambda call
                    push_context(k, v)
                else #others
                    exec(@context_stack.variable(k), v)
                end
            when ->(expr){ expr.is_a? String and expr =~ /\$(\w+)/ }
                #local variables
                var_name = $1
                @context_stack.variable(var_name)
            else
                #primitives
                expr
            end
        end

        def eval(code)
            push_context(make_lambda([], code), [])
        end
    end
end