# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "subroutine/version"

Gem::Specification.new do |spec|
  spec.name          = "subroutine"
  spec.version       = Subroutine::VERSION
  spec.authors       = ["Mike Nelson"]
  spec.email         = ["mike@mnelson.io"]
  spec.summary       = "Feature-driven operation objects."
  spec.description   = "An interface for creating feature-driven operations."
  spec.homepage      = "https://github.com/guideline-tech/subroutine"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir["lib/**/*"] + Dir["*.gemspec"]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.add_dependency "activemodel", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"
  spec.add_dependency "base64"
  spec.add_dependency "bigdecimal"
  spec.add_dependency "logger"
  spec.add_dependency "mutex_m"

  spec.add_development_dependency "actionpack", ">= 6.1"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "m"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "rake"

  spec.required_ruby_version = ">= 3.2.0"
end
