# frozen_string_literal: true

require('htx/malformed_template_error')
require('htx/template')
require('htx/text_parser')
require('htx/version')

# A Ruby compiler for HTX templates.
module HTX
  @as_module = false
  @import_path = '/htx/htx.js'
  @assign_to = 'globalThis'

  class << self
    attr_accessor(:as_module, :import_path, :assign_to)
  end

  # Public: Create a new Template instance and compile it.
  #
  # name    - String template name. Conventionally the path of the template file.
  # content - String template body/content.
  # options - Hash of Symbol keys and associated values to pass to Template#compile (optional overrides to
  #           the current configuration values).
  #
  # Examples
  #
  #   HTX.compile('/components/crew.htx', '<div>...</div>', as_module: true, import_path: '/vendor/htx.js')
  #   # => "import * as HTX from '/vendor/htx.js' [...]"
  #
  #   HTX.compile('/components/crew.htx', '<div>...</div>', as_module: false, assign_to: 'myTemplates')
  #   # => "myTemplates['/components/crew.htx'] = [...]"
  #
  # Returns the compiled template String (JavaScript code).
  def self.compile(name, content, **options)
    Template.new(name, content).compile(**options)
  end
end
