# frozen_string_literal: true

require('strscan')

module HTX
  class TextParser
    LEADING = /\A((?:[^\S\n]*\n)+)?((?:[^\S\n])+)?(?=\S)/.freeze
    TRAILING = /([\S\s]*?)(\s*?)(\n[^\S\n]*)?\z/.freeze

    NOT_ESCAPED = /(?<=^|[^\\])(?:\\\\)*/.freeze
    OF_INTEREST = /#{NOT_ESCAPED}(?<chars>[`'"]|\${)|(?<chars>{|}|\/\/|\/\*|\*\/|\n[^\S\n]*(?=\S))/.freeze
    TERMINATOR = {
      '\'' => '\'',
      '"' => '"',
      '//' => "\n",
      '/*' => '*/',
    }.freeze

    TEXT = /\S|\A[^\S\n]+\z/.freeze
    IDENTIFIER = /[_$a-zA-Z][_$a-zA-Z0-9]*/.freeze
    ASSIGNMENT = /\s*(\+|&|\||\^|\/|\*\*|<<|&&|\?\?|\|\||\*|%|-|>>>)?=/.freeze
    STATEMENT = /[{}]|(^|\s)#{IDENTIFIER}(\.#{IDENTIFIER})*(#{ASSIGNMENT}|\+\+|--|\[|\()/.freeze

    attr_reader(:type, :content, :leading, :trailing, :whitespace_buff)

    ##
    # Creates a new instance.
    #
    # * +text+ - Text to parse.
    # * +statement_allowed+ - True if statements are allowed; false if text is always a template or raw (
    #   single interpolation).
    #
    def initialize(text, statement_allowed:)
      @text = text
      @statement_allowed = statement_allowed
    end

    ##
    # Returns true if parsed text is a statement.
    #
    def statement?
      @type == :statement
    end

    ##
    # Returns true if parsed text is a single interpolation.
    #
    def raw?
      @type == :raw
    end

    ##
    # Returns true if parsed text is a template.
    #
    def template?
      @type == :template
    end

    ##
    # Parses text.
    #
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

            if !@last_indent
              @last_indent = indent
            else
              @min_indent = @last_indent if !@min_indent || @last_indent.size < @min_indent.size
              @last_indent = indent
            end
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

    ##
    # Determines type (statement, raw, or template) and adjust formatting accordingly. Called at the end of
    # parsing.
    #
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

    ##
    # Pushes a state onto the stack during parsing.
    #
    # * +state+ - State to push onto the stack.
    #
    def push_state(state)
      flush if @stack.empty?
      @stack << state
    end

    ##
    # Pops a state from the stack during parsing.
    #
    def pop_state
      state = @stack.pop

      if @stack.empty?
        flush(state)

        @interpolation_count += 1 if state == :interpolation
        @template_count += 1 if state == :template
      end
    end

    ##
    # Flushes buffer during parsing and performs statement detection if appropriate.
    #
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
