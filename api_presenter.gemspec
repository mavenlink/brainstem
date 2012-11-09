# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require "api_presenter/version"

Gem::Specification.new do |gem|
  gem.name          = "api_presenter"
  gem.authors       = ["André Arko", "Andrew Cantino", "Katlyn Daniluk", "Reid Gillette", "Sufyan Adam"]
  gem.email         = ["dev@mavenlink.com"]
  gem.description   = %q{API Presenters allows you to create presenters that know how to filter, sort, include associations, and convert your objects to Ruby hashes that can be output as JSON}
  gem.summary       = %q{Ruby-side presenters that provide a rich request API}
  gem.homepage      = "http://dev.mavenlink.com"
  gem.license       = "MIT"

  gem.files         = Dir["**/*"]
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.version       = ApiPresenter::VERSION

  gem.add_dependency "activerecord", "~> 3.0"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "rr"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "database_cleaner"
end
