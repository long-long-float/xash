require 'xash/context'

module XASH
    class ContextStack
        include Enumerable

        def initialize(evaluator)
            @evaluator = evaluator

            @context_stack = []

            #root context
            @context_stack.push(Context.new({ 'do' => [[]]}, nil))
        end

        def each
            if block_given?
                @context_stack.each{ |c| yield c }
            else
                @context_stack.each
            end
        end

        def push(context)
            @context_stack.push context
            ret = yield
            @context_stack.pop
            ret
        end

        def exist_local_variable?(name)
            @context_stack.reverse_each do |context|
                if context.exist_local_variable?(name)
                    return true
                end
            end

            cur = current
            while cur
                if cur.exist_local_variable?(name)
                    return true
                end
                cur = cur.parent
            end

            false
        end

        def variable(name)
            @context_stack.reverse_each do |context|
                if context.exist_variable?(name)
                    return context.variable(name)
                end
            end

            cur = current
            while cur
                if cur.exist_variable?(name)
                    return cur.variable(name)
                end
                cur = cur.parent
            end

            @evaluator.error UndefinedLocalVariableError, "undefined local variable `#{name}`"
        end

        def variables
            @context_stack.last.variables
        end

        def set_local_variable(name, val, with_warn = true)
            @context_stack.last.set_local_variable(name, val, with_warn)
        end

        def assign(name, val)
            @context_stack[-2].set_local_variable(name, val, true)
        end

        def reassign(name, val)
            @context_stack[-2].reset_local_variable(name, val)
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