require 'xash/context'
require 'xash/context_stack'
require 'xash/type'
require 'xash/exception'

require 'yaml'

require 'pp'

module XASH
    class Evaluator

        def error(klass, msg)
            cc = @context_stack.current
            variables = cc.variables.dup
            if cc.name == '<root>'
                variables = variables.each do |name, value|
                    if @pseudo_functions.has_key? name
                        variables[name] = '<internal>'
                    end
                end         
            end
            raise klass, {
                current_name: cc.name || 'nil',
                current_variables: variables,
                current_lambda: cc.lambda,
                parent_name: cc.parent ? cc.parent.name : 'nil',
                message: msg
            }.to_yaml
        end

        def warn(msg)
            STDERR.puts msg
        end

        def call_function(name, args)
            { name => args }
        end

        def make_lambda(args, exprs)
            { 'do' => [ { 'ar' => args }, *exprs] }
        end

        def wrap_pseudo_function(args, realname)
            make_lambda(args, [ call_function(realname, args.map{|arg| "$#{arg}"}) ])
        end

        def import_yaml(mod_name)
            context = boot({ 'do' => YAML.load_file(mod_name) })
            exec_context(context, [])
        end

        def initialize
            @context_stack = ContextStack.new(self)

            @pseudo_functions = {
                'for' => wrap_pseudo_function(['collection', 'lambda'], '__for'),
                'if' => wrap_pseudo_function(['condition', 'lambda'], '__if'),
                'case' => wrap_pseudo_function([], '__case'),

                'assign' => wrap_pseudo_function(['name', 'value'], '__assign'),
                'reassign' => wrap_pseudo_function(['name', 'value'], '__reassign'),
                'alias' => wrap_pseudo_function(['old', 'new'], '__alias'),

                'import_yaml' => wrap_pseudo_function([], '__import_yaml'),
                
                'boot' => wrap_pseudo_function(['lambda'], '__boot'),
                'method' => wrap_pseudo_function([], '__method'),
                'get' => wrap_pseudo_function(['obj', 'name'], '__get'),

                'ar' => { 'do' => [ call_function('__ar', '$args') ] },

                #for arrays
                'index' => wrap_pseudo_function(['ary', 'i'], '__index'),
                'tail' => wrap_pseudo_function(['ary'], '__tail'),

                'meta_context' => wrap_pseudo_function(%w(lambda_args lambda), '__meta_context'),
                'expr' => wrap_pseudo_function([], '__expr')
            }
            @pseudo_functions.each do |name, val|
                @context_stack.set_local_variable(name, val)
            end

            #とりあえず
            import_yaml("#{File::dirname(__FILE__)}/kernel.yml")
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
            (OPERATORS.keys + [/\\(\w+)/, /(^[-=^~|@`+;*:<.>?!%&_]+$)/]).each do |pattern|
                idx, ope = if pattern.is_a? Regexp
                            idx = tokens.index{|token| (token.is_a? String) && (m = pattern.match(token)) }
                            [ idx, idx && $~[1] ]
                        else
                            [ tokens.index(pattern), pattern ]
                        end
                if idx
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

        def boot(executable)
            case executable
            when Context
                executable
            when ->(l) { Type.lambda?(l) }
                Context.new(executable, @context_stack.current)
            else
                boot(make_lambda([], [ executable ]))
            end
        end

        def exec_context(context, args)
            context.exec(args) do |exprs|
                ret = nil
                exprs.each do |expr|
                    ret = eval_expr(expr)
                    if context.exist_variable?('next_value')
                        ret = context.variable('next_value')
                        break
                    end
                end
                ret
            end
        end

        def exec(executable, args, context_name = '<anonymous>')
            case executable
            when Context
                executable.name = context_name

                @context_stack.push(executable) do
                    exec_context(executable, args)
                end
            else #lambda and mono expr
                exec(boot(executable), args, context_name)
            end
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

                    collection = Type.to_collection(eval_expr(collection))

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
                            break exec(args[i], [])
                        end
                    end

                when '__assign'
                    check_args(v, :string)

                    name, value = v

                    @context_stack.assign(name, value)
                when '__reassign'
                    check_args(v, :string)

                    name, value = v

                    @context_stack.reassign(name, value)

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
                    boot(lambda)

                when '__method'
                    seq = @context_stack.variable('args').dup

                    obj = seq.shift
                    until seq.empty?
                        name, args = seq.shift, seq.shift
                        obj = exec(obj.variable(name), args)
                    end

                    obj

                when '__get'
                    check_args(v, :context, :string)

                    context, name = v

                    context.variable(name)

                when '__ar'
                    names = v
                    @context_stack.meta_context do
                        args = @context_stack.variable('args')
                    end
                    names.zip(args) do |name, arg|
                        @context_stack.assign(name, arg)
                    end

                when '__index'
                    check_args(v, :array, :integer)

                    ary, i = v

                    ary[i]

                when '__size'
                    check_args(v, :array)
                    v[0].size

                when '__tail'
                    check_args(v, :array)
                    ary = v[0]
                    ary[1...ary.size]

                when '__meta_context'
                    check_args(v, :array, :executable)

                    args, lambda = v

                    #current
                    @context_stack.meta_context do
                        caller = @context_stack.current
                        #caller
                        @context_stack.meta_context do
                            #meta context

                            context = boot(lambda)
                            #context.parent = current
                            args.each do |arg|
                                context.set_local_variable(arg, caller.variable(arg), true)
                            end
                            @context_stack.current.attach(context) do
                                exec_context(context, args)
                            end
                        end
                    end

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
                                if @context_stack.exist_variable?(token)
                                    r, l = stack.pop, stack.pop
                                    eval_expr(call_function(token, [l, r]))
                                else
                                    token
                                end
                            end
                    end

                    stack[0]

                #for debug
                when '__rb_inject'
                    code = v[0]
                    Kernel.eval(code, binding)

                when '__object'
                    check_args(v, :object)
                    puts "__object => #{v[0]}"
                    v[0]

                when 'do' #lambda
                    expr #for lazy evaluation

                #function call
                else #others
                    exec(@context_stack.variable(k), v, k)
                end 
            when /\$(\w+)/ #local variables
                var_name = $1
                @context_stack.variable(var_name)
            when /(\d+)(\.\.\.|\.\.)(\d+)/ #range expr
                { 'range' => [$1, $2, $3] }
            else
                #primitives
                expr
            end
        end

        def eval(code)
            exec({ 'do' => code }, [])
        end
    end
end