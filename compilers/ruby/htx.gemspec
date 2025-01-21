# frozen_string_literal: true

version = File.read(File.join(__dir__, 'VERSION')).strip.freeze

Gem::Specification.new('htx', version) do |spec|
  spec.authors       = ['Nate Pickens']
  spec.summary       = 'A Ruby compiler for HTX templates.'
  spec.description   = 'HTX is a full-featured HTML template system that is simple, lightweight, and '\
                       'highly performant. This library is a Ruby implementation of the HTX template '\
                       'compiler--it converts HTX templates to their compiled JavaScript form.'
  spec.homepage      = 'https://github.com/npickens/htx'
  spec.license       = 'MIT'
  spec.files         = Dir['lib/**/*.rb', 'CHANGELOG.md', 'LICENSE', 'README.md', 'VERSION']

  spec.metadata      = {
    'bug_tracker_uri' => 'https://github.com/npickens/htx/issues',
    'changelog_uri' => 'https://github.com/npickens/htx/blob/master/CHANGELOG.md',
    'documentation_uri' => "https://github.com/npickens/htx/blob/#{version}/README.md",
    'source_code_uri' => "https://github.com/npickens/htx/tree/#{version}",
  }

  spec.required_ruby_version     = '>= 3.0.0'
  spec.required_rubygems_version = '>= 2.0.0'

  spec.add_runtime_dependency('nokogiri', '~> 1.13')
  spec.add_development_dependency('bundler', '~> 2.0')
  spec.add_development_dependency('minitest', '~> 5.21')
end
