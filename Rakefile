require "bundler/gem_tasks"
require 'yaml'
require 'xash'

desc "Read-Eval-Print-Loop"
task :repl do
    loop do
        print '>'
        break unless code = STDIN.gets and code.strip != 'exit'
        puts '=>' + XASH.eval(YAML.load(code)).to_s
    end
end