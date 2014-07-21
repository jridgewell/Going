lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'going/version'

Gem::Specification.new do |spec|
  spec.name          = "Going"
  spec.version       = Going::VERSION
  spec.authors       = ["Justin Ridgewell"]
  spec.email         = ["justin@ridgewell.name"]
  spec.summary       = %q{Go for Ruby}
  spec.homepage      = "https://github.com/jridgewell/going"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end