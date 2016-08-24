# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'expeditor/version'

Gem::Specification.new do |spec|
  spec.name          = "expeditor"
  spec.version       = Expeditor::VERSION
  spec.authors       = ["shohei-yasutake"]
  spec.email         = ["shohei-yasutake@cookpad.com"]
  spec.license       = "MIT"

  spec.summary       = "Expeditor provides asynchronous execution and fault tolerance for microservices"
  spec.description   = "Expeditor provides asynchronous execution and fault tolerance for microservices"
  spec.homepage      = "https://github.com/cookpad/expeditor"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0.0'

  spec.add_runtime_dependency "concurrent-ruby", "~> 1.0.0"
  spec.add_runtime_dependency "concurrent-ruby-ext", "~> 1.0.0"
  spec.add_runtime_dependency "retryable", "> 1.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", ">= 3.0.0"
end
