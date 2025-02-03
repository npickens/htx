# frozen_string_literal: true

require('strscan')

module HTX
  # Handles parsing a template text node or attribute value to determine if it's a JavaScript control
  # statement or template string, and if the latter to promote single/top-level interpolations to raw
  # objects (`${this.myObject}` becomes this.myObject).
  class TextParser
    LEADING = /\A((?:[^\S\n]*\n)+)?((?:[^\S\n])+)?(?=\S)/.freeze
    TRAILING = /([\S\s]*?)(\s*?)(\n[^\S\n]*)?\z/.freeze

    NOT_ESCAPED = /(?<=^|[^\\])(?:\\\\)*/.freeze
    OF_INTEREST = %r{#{NOT_ESCAPED}(?<chars>[`'"]|\$\{)|(?<chars>\{|\}|//|/\*|\*/|\n[^\S\n]*(?=\S))}.freeze
    TERMINATOR = {
      '\'' => '\'',
      '"' => '"',
      '//' => "\n",
      '/*' => '*/',
    }.freeze

    TEXT = /\S|\A[^\S\n]+\z/.freeze
    IDENTIFIER = /[_$a-zA-Z][_$a-zA-Z0-9]*/.freeze
    ASSIGNMENT = %r{\s*(\+|&|\||\^|/|\*\*|<<|&&|\?\?|\|\||\*|%|-|>>>)?=}.freeze
    STATEMENT = /[{}]|(^|\s)#{IDENTIFIER}(\.#{IDENTIFIER})*(#{ASSIGNMENT}|\+\+|--|\[|\()/.freeze

    attr_reader(:type, :content, :leading, :trailing, :whitespace_buff)

    # Public: Create a new instance.
    #
    # text               - String text to parse.
    # statement_allowed: - Boolean indicating if the text is allowed to be a statement (false for attribute
    #                      values and <htx-content> text content).
    def initialize(text, statement_allowed:)
      @text = text
      @statement_allowed = statement_allowed
    end

    # Public: Check if the parsed text was determined to be a JavaScript statement.
    #
    # Returns the boolean result.
    def statement?
      @type == :statement
    end

    # Public: Check if the parsed text was determined to be a single top-level interpolation.
    #
    # Returns the boolean result.
    def raw?
      @type == :raw
    end

    # Public: Check if the parsed text was determined to be a JavaScript template string.
    #
    # Returns the boolean result.
    def template?
      @type == :template
    end

    # Parse the text.
    #
    # Returns the parsed text String with any needed adjustments made (single top-level interpolations
    # promoted to non-strings).
    def parse
      @type = nil
      @content = +''

      @first_indent = nil
      @min_indent = nil
      @last_indent = nil

      @buffer = +''
      @stack = []
      curlies = []
      ignore_end = nil

      @has_text = false
      @is_statement = false
      @template_count = 0
      @interpolation_count = 0

      scanner = StringScanner.new(@text)

      scanner.scan(LEADING)
      @leading_newlines = scanner[1]
      @leading_indent = @first_indent = scanner[2]
      @leading = scanner[0] if @leading_newlines || @leading_indent

      until scanner.eos?
        if (scanned = scanner.scan_until(OF_INTEREST))
          ignore = @stack.last == :ignore
          template = @stack.last == :template
          interpolation = @stack.last == :interpolation
          can_ignore = (@stack.empty? && @statement_allowed) || interpolation
          can_template = @stack.empty? || interpolation
          can_interpolate = @stack.empty? || template

          chars = scanner[:chars]
          @buffer << scanned.chomp!(chars)

          if chars[0] == "\n"
            indent = chars.delete_prefix("\n")

            if @last_indent && (!@min_indent || @last_indent.size < @min_indent.size)
              @min_indent = @last_indent
            end

            @last_indent = indent
          end

          if can_ignore && (ignore_end = TERMINATOR[chars])
            push_state(:ignore)
            @buffer << chars
          elsif ignore && chars == ignore_end
            @buffer << chars
            pop_state
            ignore_end = nil
          elsif can_template && chars == '`'
            push_state(:template)
            @buffer << chars
          elsif template && chars == '`'
            @buffer << chars
            pop_state
          elsif can_interpolate && chars == '${'
            push_state(:interpolation)
            curlies << 1
            @buffer << chars
          elsif interpolation && (curlies[-1] += (chars == '{' && 1) || (chars == '}' && -1) || 0) == 0
            @buffer << chars
            curlies.pop
            pop_state
          else
            @buffer << chars
          end
        else
          scanner.scan(TRAILING)

          @buffer << scanner[1]
          @trailing = scanner[2] == '' ? nil : scanner[2]
          @whitespace_buff = scanner[3]
        end
      end

      flush(@stack.last)
      finalize

      @content
    end

    private

    # Internal: Determine the text type (statement, raw, or template) after parsing and adjust the string
    # accordingly.
    #
    # Returns nothing.
    def finalize
      if @is_statement
        @type = :statement
        @content.insert(0, @leading) && @leading = nil if @leading
        @content.insert(-1, @trailing) && @trailing = nil if @trailing
      elsif !@has_text && @template_count == 0 && @interpolation_count == 1
        @type = :raw
        @content.delete_prefix!('${')
        @content.delete_suffix!('}')

        if @content.empty?
          @type = :template
          @content = '``'
        end
      else
        @type = :template

        if !@has_text && @template_count == 1 && @interpolation_count == 0
          @quoted = true
          @outdent = @min_indent
          @content.delete_prefix!('`')
          @content.delete_suffix!('`')
        else
          @outdent = [@first_indent, @min_indent, @last_indent].compact.min
        end

        @content.gsub!(/(?<=\n)([^\S\n]+$|#{@outdent})/, '') if @outdent && !@outdent.empty?

        unless @quoted
          @content.insert(0, @leading) && @leading = nil if @leading && !@leading_newlines
          @content.insert(-1, @trailing) && @trailing = nil if @trailing && !@trailing.include?("\n")
        end

        @content.insert(0, '`').insert(-1, '`')
      end
    end

    # Internal: Push a state onto the stack during parsing.
    #
    # state - Symbol state name.
    #
    # Returns nothing.
    def push_state(state)
      flush if @stack.empty?
      @stack << state
    end

    # Internal: Pop a state from the stack during parsing.
    #
    # Returns nothing.
    def pop_state
      state = @stack.pop

      if @stack.empty?
        flush(state)

        @interpolation_count += 1 if state == :interpolation
        @template_count += 1 if state == :template
      end
    end

    # Internal: Flush the buffer during parsing and perform statement detection if appropriate.
    #
    # state - Last Symbol state name that was parsed.
    #
    # Returns nothing.
    def flush(state = nil)
      return if @buffer.empty?

      if !state || state == :text
        @has_text ||= @buffer.match?(TEXT)
        @is_statement ||= @buffer.match?(STATEMENT) if @statement_allowed
      end

      @content << @buffer
      @buffer.clear
    end
  end
end
