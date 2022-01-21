# frozen_string_literal: true

module HTX
  ##
  # Error class used when a problem is encountered processing a template.
  #
  class MalformedTemplateError < StandardError
    ##
    # Creates a new instance.
    #
    # * +message+ - Description of the error.
    # * +name+ - Name of the template.
    # * +node+ - Nokogiri node being processed when the error was encountered (optional).
    #
    def initialize(message, name, node = nil)
      if node
        line = node.line
        line = node.parent.line if line < 1
        line = nil if line == -1
      end

      super("Malformed template #{name}#{":#{line}" if line}: #{message}")
    end
  end
end
