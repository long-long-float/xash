module XASH
    class Context
        attr_accessor :name, :parent
        attr_reader :lambda

        def initialize(lambda, parent)
            @variable_table = {}
            @lambda = lambda['do']
            @parent = parent
            @name = '<anonymous>'
        end

        def exec(args)
            exprs = @lambda
            set_local_variable('it', args[0], false)
            set_local_variable('args', args, false)
            
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

        def exist_variable?(name)
            attaching_context_call(:exist_variable?, name) || @variable_table.include?(name) 
        end

        def variable(name)
            attaching_context_call(:variable, name) || @variable_table[name] 
        end

        def variables
            @variable_table.merge(attaching_context_call(:variables) || {})
        end

        def set_local_variable(name, val, with_warn)
            if with_warn && @variable_table.key?(name)
                warn "`#{name}` has been already assigned!"
            end
            @variable_table[name] = val
        end

        def reset_local_variable(name, val)
            unless @variable_table.include? name
                error UndefinedLocalVariableError, "undefined local variable `#{name}`"
            end
            @variable_table[name] = val
        end
    end
end