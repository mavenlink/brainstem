# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require "brainstem/version"

Gem::Specification.new do |gem|
  gem.name          = "brainstem"
  gem.authors       = ["Sufyan Adam", "André Arko", "Andrew Cantino", "Katlyn Daniluk", "Reid Gillette"]
  gem.email         = ["dev@mavenlink.com"]
  gem.description   = %q{Brainstem allows you to create rich API presenters that know how to filter, sort, and include associations.}
  gem.summary       = %q{ActiveRecord presenters with a rich request API}
  gem.homepage      = "http://developer.mavenlink.com"
  gem.license       = "MIT"

  gem.files         = Dir["**/*"]
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.version       = Brainstem::VERSION

  gem.add_dependency "activerecord", "~> 3.0"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "redcarpet" # for markdown in yard
  gem.add_development_dependency "rr"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "yard"
end
