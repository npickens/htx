# frozen_string_literal: true

require('nokogiri')

##
# A Ruby compiler for HTX templates.
#
class HTX
  VERSION = '0.0.4'

  CHILDLESS = 0b01
  TEXT_NODE = 0b10
  FLAG_BITS = 2

  INDENT_DEFAULT = '  '
  DYNAMIC_KEY_ATTR = 'htx-key'

  LEADING_WHITESPACE = /\A[ \t]*\n[ \t]*/.freeze
  TRAILING_WHITESPACE = /\n[ \t]*\z/.freeze
  NON_BLANK_NON_FIRST_LINE = /(?<=\n)[ \t]*(?=\S)/.freeze
  NEWLINE_NON_BLANK = /\n(?=[^\n])/.freeze
  INDENT_GUESS = /^[ \t]+/.freeze

  END_STATEMENT_END = /(;|\n|\{|\})[ \t]*\z/.freeze
  BEGIN_STATEMENT_END = /\A[ \t]*(;|\{|\n|\})/.freeze
  END_WHITESPACE = /\s\z/.freeze
  BEGIN_WHITESPACE = /\A\s/.freeze

  RAW_VALUE = /\A\s*\${([\S\s]*)}\s*\z/.freeze
  TEMPLATE_STRING = /\A\s*`([\S\s]*)`\s*\z/.freeze
  INTERPOLATION = /\$\\?{([^}]*})?/.freeze
  HTML_ENTITY = /&([a-zA-Z]+|#\d+|x[0-9a-fA-F]+);/.freeze
  NON_CONTROL_STATEMENT = /#{INTERPOLATION}|(#{HTML_ENTITY})/.freeze
  CONTROL_STATEMENT = /[{}();]/.freeze
  CLOSE_STATEMENT = /;?\s*htx\.close\((\d*)\);?(\s*)\z/.freeze

  EMPTY_HASH = {}.freeze

  ##
  # Convenience method to create a new instance and immediately call compile on it.
  #
  def self.compile(name, template, options = EMPTY_HASH)
    new(name, template).compile(options)
  end

  ##
  # Creates a new HTX instance. Conventionally the path of the template file is used for the name, but it
  # can be anything.
  #
  def initialize(name, template)
    @name = name
    @template = template
  end

  ##
  # Compiles the HTX template. Options:
  #
  # * :indent - Indent output by this number of spaces if Numeric, or by this string if a String (if the
  #     latter, may only contain space and tab characters).
  # * :assign_to - Assign the template function to this JavaScript object instead of the `window` object.
  #
  def compile(options = EMPTY_HASH)
    doc = Nokogiri::HTML::DocumentFragment.parse(@template)
    root_nodes = doc.children.select { |n| n.element? || (n.text? && n.text.strip != '') }

    if (text_node = root_nodes.find(&:text?))
      raise(MalformedTemplateError.new('text nodes are not allowed at root level', @name, text_node))
    elsif root_nodes.size == 0
      raise(MalformedTemplateError.new('a root node is required', @name))
    elsif root_nodes.size > 1
      raise(MalformedTemplateError.new("root node already defined on line #{root_nodes[0].line}", @name,
          root_nodes[1]))
    end

    @compiled = ''.dup
    @static_key = 0

    @indent =
      if options[:indent].kind_of?(Numeric)
        ' ' * options[:indent]
      elsif options[:indent].kind_of?(String) && options[:indent] !~ /^[ \t]+$/
        raise("Invalid :indent value #{options[:indent].inspect}: only spaces and tabs are allowed")
      else
        options[:indent] || @template[INDENT_GUESS] || INDENT_DEFAULT
      end

    process(doc)
    @compiled.rstrip!

    <<~EOS
      #{options[:assign_to] || 'window'}['#{@name}'] = function(htx) {
      #{@indent}#{@compiled}
      }
    EOS
  end

  private

  ##
  # Processes a DOM node's descendents.
  #
  def process(base)
    base.children.each do |node|
      next unless node.element? || node.text?

      dynamic_key = process_value(node.attr(DYNAMIC_KEY_ATTR), :attr)

      if node.text? || node.name == ':'
        if (non_text_node = node.children.find { |n| !n.text? })
          raise(MalformedTemplateError.new('dummy tags may not contain child tags', @name, non_text_node))
        end

        text = (node.text? ? node : node.children).text

        if (value = process_value(text))
          append(
            "#{indent(text[LEADING_WHITESPACE])}"\
            "htx.node(#{[
              value,
              dynamic_key,
              ((@static_key += 1) << FLAG_BITS) | TEXT_NODE,
            ].compact.join(', ')})"\
            "#{indent(text[TRAILING_WHITESPACE])}"
          )
        else
          append(indent(text))
        end
      else
        attrs = node.attributes.inject([]) do |attrs, (_, attr)|
          next attrs if attr.name == DYNAMIC_KEY_ATTR

          attrs << "'#{ATTR_MAP[attr.name] || attr.name}'"
          attrs << process_value(attr.value, :attr)
        end

        childless = node.children.empty? || (node.children.size == 1 && node.children[0].text.strip == '')

        append("htx.node(#{[
          "'#{TAG_MAP[node.name] || node.name}'",
          attrs,
          dynamic_key,
          ((@static_key += 1) << FLAG_BITS) | (childless ? CHILDLESS : 0),
        ].compact.flatten.join(', ')})")

        unless childless
          process(node)

          count = ''
          @compiled.sub!(CLOSE_STATEMENT) do
            count = $1 == '' ? 2 : $1.to_i + 1
            $2
          end

          append("htx.close(#{count})")
        end
      end
    end
  end

  ##
  # Appends a string to the compiled template function string with appropriate punctuation and/or whitespace
  # inserted.
  #
  def append(text)
    if @compiled == ''
      # Do nothing.
    elsif @compiled !~ END_STATEMENT_END && text !~ BEGIN_STATEMENT_END
      @compiled << '; '
    elsif @compiled !~ END_WHITESPACE && text !~ BEGIN_WHITESPACE
      @compiled << ' '
    elsif @compiled[-1] == "\n"
      @compiled << @indent
    end

    @compiled << text
  end

  ##
  # Indents each line of a string (except the first).
  #
  def indent(text)
    return '' unless text

    text.gsub!(NEWLINE_NON_BLANK, "\n#{@indent}")
    text
  end

  ##
  # Processes, formats, and encodes an attribute or text node value. Returns nil if the value is determined
  # to be a control statement.
  #
  def process_value(text, is_attr = false)
    return nil if text.nil? || (!is_attr && text.strip == '')

    if (value = text[RAW_VALUE, 1])
      # Entire text is enclosed in ${...}.
      value.strip!
      quote = false
    elsif (value = text[TEMPLATE_STRING, 1])
      # Entire text is enclosed in backticks (template string).
      quote = true
    elsif is_attr || text.gsub(NON_CONTROL_STATEMENT, '') !~ CONTROL_STATEMENT
      # Text is an attribute value or doesn't match control statement pattern.
      value = text.dup
      quote = true
    else
      return nil
    end

    # Strip one leading and trailing newline (and attached spaces) and perform outdent. Outdent amount
    # calculation ignores everything before the first newline in its search for the least-indented line.
    outdent = value.scan(NON_BLANK_NON_FIRST_LINE).min
    value.gsub!(/#{LEADING_WHITESPACE}|#{TRAILING_WHITESPACE}|^#{outdent}/, '')
    value.insert(0, '`').insert(-1, '`') if quote

    # Ensure any Unicode characters get converted to Unicode escape sequences. Also note that since Nokogiri
    # converts HTML entities to Unicode characters, this causes them to be properly passed to
    # `document.createTextNode` calls as Unicode escape sequences rather than (incorrectly) as HTML
    # entities.
    value.encode('ascii', fallback: ->(c) { "\\u#{c.ord.to_s(16).rjust(4, '0')}" })
  end

  class MalformedTemplateError < StandardError
    def initialize(message, name, node = nil)
      if node
        line = node.line
        line = node.parent.line if line < 1
        line = nil if line == -1
      end

      super("Malformed template #{name}#{":#{line}" if line}: #{message}")
    end
  end

  # The Nokogiri HTML parser downcases all tag and attribute names, but SVG tags and attributes are case
  # sensitive and often mix cased. These maps are used to restore the correct case of such tags and
  # attributes.
  TAG_MAP = %w[
    animateMotion animateTransform clipPath feBlend feColorMatrix feComponentTransfer feComposite
    feConvolveMatrix feDiffuseLighting feDisplacementMap feDistantLight feDropShadow feFlood feFuncA feFuncB
    feFuncG feFuncR feGaussianBlur feImage feMerge feMergeNode feMorphology feOffset fePointLight
    feSpecularLighting feSpotLight feTile feTurbulence foreignObject linearGradient radialGradient textPath
  ].map { |tag| [tag.downcase, tag] }.to_h.freeze

  ATTR_MAP = %w[
    allowReorder attributeName attributeType autoReverse baseFrequency baseProfile calcMode clipPathUnits
    contentScriptType contentStyleType diffuseConstant edgeMode externalResourcesRequired filterRes
    filterUnits glyphRef gradientTransform gradientUnits kernelMatrix kernelUnitLength keyPoints keySplines
    keyTimes lengthAdjust limitingConeAngle markerHeight markerUnits markerWidth maskContentUnits maskUnits
    numOctaves pathLength patternContentUnits patternTransform patternUnits pointsAtX pointsAtY pointsAtZ
    preserveAlpha preserveAspectRatio primitiveUnits refX refY referrerPolicy repeatCount repeatDur
    requiredExtensions requiredFeatures specularConstant specularExponent spreadMethod startOffset
    stdDeviation stitchTiles surfaceScale systemLanguage tableValues targetX targetY textLength viewBox
    viewTarget xChannelSelector yChannelSelector zoomAndPan
  ].map { |attr| [attr.downcase, attr] }.to_h.freeze
end
