lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'fgi'
  spec.version       = '1.1.5'
  spec.authors       = ['Julien Philibin', 'Matthieu Gourvénec']
  spec.email         = %w[philib_j@modulotech.fr gourve_m@modulotech.fr]
  spec.summary       = 'Process and workflow simplifier for git projects.'
  spec.description   = 'Fast Git Issues.'
  spec.homepage      = 'https://www.modulotech.fr'

  spec.files = Dir[
                 'Rakefile',
                 '{bin,lib,man,test,spec}/**/*',
                 'README*',
                 'LICENSE*'
               ] & `git ls-files -z`.split("\0")

  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_path  = 'lib'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
