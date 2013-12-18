module XASH
    class Context
        attr_reader :lambda

        def initialize(lambda, lambda_args, parent)
            @variable_table = {}

            @lambda = lambda

            call(lambda_args)

            @parent = parent
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

        def defined_variable?(name)
            @variable_table.include?(name) || @attached_table && @attached_table.include?(name)
        end

        def variable(name)
            @variable_table[name] || @attached_table && @attached_table[name]
        end

        def variables
            @variable_table.merge(@attached_table || {})
        end

        def set_local_variable(name, val, with_warn = false)
            if with_warn && @variable_table.key?(name)
                warn "`#{name}` has been already assigned!"
            end
            @variable_table[name] = val
        end

        def call(lambda_args)
            lambda_args = lambda_args.dup
            @lambda[0].each do |arg|
                @variable_table[arg] = lambda_args.shift
            end

            self
        end
    end
end