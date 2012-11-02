# -*- encoding: utf-8 -*-
require File.expand_path('../lib/api_presenters/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Andr\303\251 Arko & Katlyn Daniluk"]
  gem.email         = ["pair+andr\303\251+katlyn@mavenlink.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "api_presenters"
  gem.require_paths = ["lib"]
  gem.version       = ApiPresenters::VERSION
end
