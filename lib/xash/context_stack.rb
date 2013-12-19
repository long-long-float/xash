require 'xash/context'

module XASH
    class ContextStack
        def initialize(evaluator)
            @evaluator = evaluator

            @context_stack = []

            #root context
            @context_stack.push(Context.new({ 'do' => [[]]}, nil))
        end

        def push(context)
            @context_stack.push context
            ret = yield
            @context_stack.pop
            ret
        end

        def exist_local_variable?(name)
            @context_stack.reverse_each do |context|
                if context.defined_variable?(name)
                    return true
                end
            end
            false
        end

        def variable(name)
            @context_stack.reverse_each do |context|
                if context.exist_local_variable?(name)
                    return context.variable(name)
                end
            end
            @evaluator.error UndefinedLocalVariableError, "undefined local variable `#{name}`"
        end

        def variables
            @context_stack.last.variables
        end

        def set_local_variable(name, val, with_warn = false)
            @context_stack.last.set_local_variable(name, val, with_warn)
        end

        def assign(name, val)
            @context_stack[-2].set_local_variable(name, val)
        end

        def meta_context
            current = @context_stack.pop
            ret = yield
            @context_stack.push(current)
            ret
        end

        def current
            @context_stack.last
        end
    end
end