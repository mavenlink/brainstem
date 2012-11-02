# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require "api_presenters/version"

Gem::Specification.new do |gem|
  gem.name          = "api_presenters"
  gem.authors       = ["André Arko & Katlyn Daniluk"]
  gem.email         = ["pair+andré+katlyn@mavenlink.com"]
  gem.description   = %q{API Presenters allows you to create presenters that know how to filter, sort, include associations, and convert your objects to Ruby hashes that can be output as JSON}
  gem.summary       = %q{Ruby-side presenters that provide a rich request API}
  gem.homepage      = "http://dev.mavenlink.com"
  gem.license       = "MIT"

  gem.files         = Dir["**/*"]
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.version       = ApiPresenters::VERSION
end
