# -*- encoding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require "api_presenter/version"

Gem::Specification.new do |gem|
  gem.name          = "brainstem"
  gem.authors       = ["Sufyan Adam", "André Arko", "Andrew Cantino", "Katlyn Daniluk", "Reid Gillette"]
  gem.email         = ["dev@mavenlink.com"]
  gem.description   = %q{Brainstem allows you to create presenters that know how to filter, sort, include associations, and then convert your objects to Ruby hashes that can be output in another format, like JSON}
  gem.summary       = %q{ActiveRecord presenters with a rich request API}
  gem.homepage      = "http://dev.mavenlink.com"
  gem.license       = "MIT"

  gem.files         = Dir["**/*"]
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.version       = ApiPresenter::VERSION

  gem.add_dependency "activerecord", "~> 3.0"

  gem.add_development_dependency "database_cleaner"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "redcarpet" # for markdown in yard
  gem.add_development_dependency "rr"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "emoji-rspec"
end
