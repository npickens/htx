# frozen_string_literal: true

version = File.read(File.expand_path('../../../VERSION', __FILE__)).strip

Gem::Specification.new('htx', version) do |spec|
  spec.authors       = ['Nate Pickens']
  spec.summary       = 'A Ruby compiler for HTX templates.'
  spec.description   = 'HTX is a full-featured HTML template system that is simple, lightweight, and '\
                       'highly performant. This library is a Ruby implementation of the HTX template '\
                       'compiler--it converts HTX templates to their compiled JavaScript form.'
  spec.homepage      = 'https://github.com/npickens/htx'
  spec.license       = 'MIT'
  spec.files         = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'VERSION']

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
  else
    raise('RubyGems 2.0 or newer is required to protect against public gem pushes.')
  end

  spec.required_ruby_version = '>= 2.6.0'

  spec.add_runtime_dependency('nokogiri', '~> 1.13')
  spec.add_development_dependency('bundler', '~> 2.0')
  spec.add_development_dependency('minitest', '>= 5.11.2', '< 6.0.0')
end
