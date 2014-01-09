require 'test/unit'

class OperatorTest < Test::Unit::TestCase
    def test_definition
        assert_equal 2, XASH_eval(:definition_operator)
    end
end