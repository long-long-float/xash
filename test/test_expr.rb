require 'test/unit'

class ExprTest < Test::Unit::TestCase

    def expr(*tokens)
        XASH.eval [{ 'expr' => tokens }]
    end

    #+ - div mul
    def test_basic_calc
        assert_equal 6, expr(1, '+', 2, '+', 3)
        assert_equal 26, expr(2, 'mul', 3, '+', 4, 'mul', 5)

        assert_equal 1, expr(5, 'mod', 2)
    end

    #or and xor
    def test_logical_calc
        assert_equal true, expr(true, 'or', false)
        assert_equal false, expr(true, 'and', false)
        assert_equal true, expr(true, 'xor', false)
    end

    #== /=
    def test_equivalent_calc
        assert_equal true, expr(1, '+', 2, '==', 3)
        assert_equal false, expr(1, '+', 2, '/=', 3)
    end
end