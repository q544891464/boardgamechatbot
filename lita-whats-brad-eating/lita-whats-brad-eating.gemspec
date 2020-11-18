Gem::Specification.new do |spec|
  spec.name          = "lita-whats-brad-eating"
  spec.version       = "0.1.0"
  spec.authors       = ["q544891464"]
  spec.email         = ["weifanchen1997@gmail.com"]
  spec.description   = "hahaha"
  spec.summary       = "hahaha"
  spec.homepage      = "https://github.com/q544891464"
  spec.license       = "MIT"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.8"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rspec", ">= 3.0.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "coveralls"
end
