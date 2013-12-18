require 'test/unit'

class ContextTest < Test::Unit::TestCase
    def test_meta_context
        assert_equal 10, XASH_eval(:context)
    end
end