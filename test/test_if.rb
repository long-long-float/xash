require 'test/unit'

class IfTest < Test::Unit::TestCase

    def if_expr(cond, lambda)
        XASH.eval [{ 'if' => [cond, lambda] }]
    end

    def test_basic
        assert_equal 'ok', if_expr([true], 'ok')
        assert_equal nil, if_expr([false], 'ok')

        assert_equal 'ok', if_expr([5, 'mod', 2, '==', 1], 'ok')
    end
end