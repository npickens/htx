# frozen_string_literal: true

require('htx/malformed_template_error')
require('htx/template')
require('htx/text_parser')
require('htx/version')

##
# A Ruby compiler for HTX templates.
#
module HTX
  EMPTY_HASH = {}.freeze

  @as_module = false
  @import_path = '/htx/htx.js'
  @assign_to = 'globalThis'

  class << self; attr_accessor(:as_module, :import_path, :assign_to); end

  ##
  # Convenience method to create a new Template instance and compile it.
  #
  # * +name+ - Template name. Conventionally the path of the template file.
  # * +content+ - Template content.
  # * +options+ - Options to be passed to Template#compile.
  #
  def self.compile(name, content, options = EMPTY_HASH)
    Template.new(name, content).compile(**options)
  end
end
