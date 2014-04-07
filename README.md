# Xash

## Installation

Add this line to your application's Gemfile:

    gem 'xash'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install xash

## Testing

    $ rake test

## Example

samples/fizzbuzz.yml
```ruby
#FizzBuzz
- for: [1..10,
    do: [ ar: [i],
        case: [
            [$i, mod, 15, ==, 0], FizzBuzz,
            [$i, mod, 3, ==, 0], Fizz,
            [$i, mod, 5, ==, 0], Buzz,
            do: [$i]
        ]
    ]
]
```

## Document

see [wiki](https://github.com/long-long-float/xash/wiki/Document)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
