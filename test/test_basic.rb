require 'test/unit'

class BasicTest < Test::Unit::TestCase
    def test_reassign
        assert_equal 10, XASH_eval(:reassign)
    end
end