module XASH
    class Type
        class << self

            {
                array: Array,
                object: Hash,
                string: String,
                integer: Integer,
                context: Context
            }.each do |name, klass|
                define_method "#{name}?" do |obj|
                    obj.is_a? klass
                end
            end

            def lambda?(lambda)
                lambda.is_a? Hash and lambda.to_a[0][0] == 'do'
            end

            def collection?(collection)
                collection.is_a? Range or collection.is_a? String or collection.respond_to? :to_a
            end

            def executable?(executable)
                lambda?(executable) or context?(executable)
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
        end
    end
end
