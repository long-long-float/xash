require 'test/unit'
require 'xash'
require 'yaml'

class Test::Unit::TestCase
    def XASH_eval(name)
        XASH.eval(YAML.load_file("samples/#{name}.yml"))
    end
end