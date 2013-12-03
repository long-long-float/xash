require 'xash'
require 'yaml'
require 'pp'
pp XASH.eval(YAML.load_file(ARGV[0]))