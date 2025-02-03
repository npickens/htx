# frozen_string_literal: true

module HTX
  # Error class used when a problem is encountered with a template during compilation.
  class MalformedTemplateError < StandardError
    # Public: Create a new instance.
    #
    # message - String description of the error.
    # name    - String name of the template.
    # node    - Nokogiri::XML::Node node being processed when the error was encountered (optional).
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
