# -*- encoding: utf-8 -*-
require File.expand_path('../lib/mzl/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Kyle Brett"]
  gem.email         = ["kyle@kylebrett.com"]
  gem.description   = %q{Ridiculous metaprogramming for almost no reason.}
  gem.summary       = %q{Metaprogramming library for DSLs}
  gem.homepage      = "http://github.com/dashkb/mzl"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "mzl"
  gem.require_paths = ["lib"]
  gem.version       = Mzl::VERSION
end
