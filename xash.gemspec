# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'xash/version'

Gem::Specification.new do |spec|
  spec.name          = "xash"
  spec.version       = Xash::VERSION
  spec.authors       = ["long-long-float"]
  spec.email         = ["niinikazuki@yahoo.co.jp"]
  spec.description   = %q{XASH is a external DSL which can be written in YAML!}
  spec.summary       = %q{}
  spec.homepage      = "https://github.com/long-long-float/xash"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "roconv"
end
