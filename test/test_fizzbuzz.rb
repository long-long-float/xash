require 'test/unit'

class FizzBuzzTest < Test::Unit::TestCase
    def test_fizzbuzz
        assert_equal [1, 2, "Fizz", 4, "Buzz", "Fizz", 7, 8, "Fizz", "Buzz"], XASH_eval(:fizzbuzz)
    end
end