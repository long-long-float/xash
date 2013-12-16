require 'test/unit'

class ForTest < Test::Unit::TestCase
    def test_range
        assert_equal [*1..10], XASH_eval(:for_range)
    end

    def test_array
        assert_equal [1, 9, 9, 5], XASH_eval(:for_array)
    end
end