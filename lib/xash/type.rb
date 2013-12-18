module XASH
    class Type
        class << self

            def array?(array)
                array.class == Array
            end

            def object?(object)
                object.class == Hash
            end

            def lambda?(lambda)
                lambda.is_a? Hash and lambda.to_a[0][0] == 'do'
            end

            def string?(string)
                string.class == String
            end

            def integer?(integer)
                integer.class == Fixnum
            end

            def collection?(collection)
                collection.is_a? Range or collection.is_a? String or collection.respond_to? :to_a
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
