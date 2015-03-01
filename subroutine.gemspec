# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'subroutine/version'

Gem::Specification.new do |spec|
  spec.name          = "subroutine"
  spec.version       = Subroutine::VERSION
  spec.authors       = ["Mike Nelson"]
  spec.email         = ["mike@mnelson.io"]
  spec.summary       = %q{An interface for creating feature-driven operations.}
  spec.description   = %q{An interface for creating feature-driven operations.}
  spec.homepage      = "https://github.com/mnelson/subroutine"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(gemfiles|test)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activemodel", ">= 4.0.0"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
end
