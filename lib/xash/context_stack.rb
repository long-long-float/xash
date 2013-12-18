require 'xash/context'

module XASH
    class ContextStack
        def initialize(evaluator)
            @evaluator = evaluator

            @context_stack = []

            #root context
            @context_stack.push(Context.new([[]], [], nil))
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
                if context.defined_variable?(name)
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

        def context(lambda, lambda_args)
            context = case lambda
                    when Hash #->(l) { lambda? l } #TODO: call lambda?
                        Context.new(lambda['do'], lambda_args, current)
                    when Context
                        lambda.call(lambda_args)
                    end

            @context_stack.push context
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
            @context_stack.last
        end
    end
end