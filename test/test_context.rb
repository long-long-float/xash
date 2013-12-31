require 'test/unit'

class ContextTest < Test::Unit::TestCase
    def test_meta_context
        assert_equal 10, XASH_eval(:context)
    end

    def test_closure
        assert_equal 'long_long_float', XASH_eval(:closure)
    end

    def test_class
        assert_equal 'long_long_float : 18', XASH_eval(:class)
    end

    def test_extend
        assert_equal %w(overridden func2), XASH_eval(:extend)
    end

    def test_get
        assert_equal 'long_long_float', XASH_eval(:context_get)
    end
end