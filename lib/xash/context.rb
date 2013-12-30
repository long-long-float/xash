module XASH
    class Context
        attr_accessor :name
        attr_reader :lambda, :parent

        def initialize(lambda, parent)
            @variable_table = {}
            @lambda = lambda['do']
            @parent = parent
        end

        def exec(args)
            lambda_arg, *exprs = @lambda

            set_local_variable('it', args[0])
            set_local_variable('args', args)

            lambda_arg.each_with_index do |arg, i|
                set_local_variable(arg, args[i], false)
            end

            yield(exprs)
        end

        def attach(context)
            @attaching_context = context
            ret = yield
            @attaching_context = nil
            ret
        end

        def attaching_context_call(name, *args)
            @attaching_context && @attaching_context.send(name, *args)
        end

        def exist_local_variable?(name)
            attaching_context_call(:exist_local_variable?, name) || @variable_table.include?(name) 
        end

        def variable(name)
            attaching_context_call(:variable, name) || @variable_table[name] 
        end

        def variables
            @variable_table.merge(attaching_context_call(:variables) || {})
        end

        def set_local_variable(name, val, with_warn = true)
            if with_warn && @variable_table.key?(name)
                warn "`#{name}` has been already assigned!"
            end
            @variable_table[name] = val
        end
    end
end