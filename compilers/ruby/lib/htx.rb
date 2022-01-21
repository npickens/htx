# frozen_string_literal: true

require('htx/malformed_template_error')
require('htx/template')
require('htx/version')

##
# A Ruby compiler for HTX templates.
#
module HTX
  EMPTY_HASH = {}.freeze

  ##
  # Convenience method to create a new Template instance and compile it.
  #
  def self.compile(name, template, options = EMPTY_HASH)
    Template.new(name, template).compile(**options)
  end

  ##
  # DEPRECATED. Use HTX::Template.new instead. HTX was formerly a class that would be instantiated for
  # compilation. This method allows HTX.new calls to continue working (but support will be removed in the
  # near future).
  #
  # * +name+ - Name of the template. Conventionally the path of the template file is used for the name,
  #   but it can be anything.
  # * +content+ - Template content string.
  #
  def self.new(name, content)
    warn('HTX.new is deprecated. Please use HTX::Template.new instead.')

    Template.new(name, content)
  end
end
