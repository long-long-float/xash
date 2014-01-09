require 'xash/context'

module XASH
    class ContextStack
        include Enumerable

        def initialize(evaluator)
            @evaluator = evaluator

            @context_stack = []

            #root context
            root = Context.new({ 'do' => [] }, nil)
            root.name = '<root>'
            @context_stack.push(root)
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

        def get_variable(name)
            #search order
            #parents -> context_stack(attached -> local)
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

            raise UndefinedLocalVariableError, "undefined local variable `#{name}`"
        end

        def exist_variable?(name)
            get_variable(name)
        rescue
            false
        else
            true
        end

        def variable(name)
            get_variable(name)
        rescue
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