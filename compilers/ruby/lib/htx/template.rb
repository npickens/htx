# frozen_string_literal: true

require('nokogiri')

module HTX
  class Template
    ELEMENT   = 0b001
    CHILDLESS = 0b010
    XMLNS     = 0b100
    FLAG_BITS = 3

    INDENT_DEFAULT = '  '
    CONTENT_TAG = 'htx-content'
    DYNAMIC_KEY_ATTR = 'htx-key'

    DEFAULT_XMLNS = {
      'math' => 'http://www.w3.org/1998/Math/MathML',
      'svg' => 'http://www.w3.org/2000/svg',
    }.freeze

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
    UNESCAPED_BACKTICK = /(?<!\\)((\\\\)*)`/.freeze
    CLOSE_STATEMENT = /;?\s*htx\.close\((\d*)\);?(\s*)\z/.freeze

    ##
    # Returns false. In the near future when support for the <:> tag has been dropped (in favor of
    # <htx-text>), will return true if Nokogiri's HTML5 parser is available. To use it now, monkey patch
    # this method to return true.
    #
    def self.html5_parser?
      false # !!defined?(Nokogiri::HTML5)
    end

    ##
    # Returns Nokogiri's HTML5 parser if available and enabled, and Nokogiri's regular HTML parser
    # otherwise.
    #
    def self.nokogiri_parser
      html5_parser? ? Nokogiri::HTML5::DocumentFragment : Nokogiri::HTML::DocumentFragment
    end

    ##
    # Creates a new HTX instance.
    #
    # * +name+ - Name of the template. Conventionally the path of the template file is used for the name,
    #   but it can be anything.
    # * +content+ - Template content string.
    #
    def initialize(name, content)
      @name = name
      @content = content
    end

    ##
    # Compiles the HTX template.
    #
    # * +indent+ - Indent output by this number of spaces if Numeric, or by this string if a String (if the
    #   latter, may only contain space and tab characters).
    # * +assign_to+ - Assign the template function to this JavaScript object instead of the <tt>window</tt>
    #   object.
    #
    def compile(indent: nil, assign_to: 'window')
      doc = self.class.nokogiri_parser.parse(@content)
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
        if indent.kind_of?(Numeric)
          ' ' * indent
        elsif indent.kind_of?(String) && indent !~ /^[ \t]+$/
          raise("Invalid indent value #{indent.inspect}: only spaces and tabs are allowed")
        else
          indent || @content[INDENT_GUESS] || INDENT_DEFAULT
        end

      process(doc)
      @compiled.rstrip!

      <<~EOS
        #{assign_to}['#{@name}'] = function(htx) {
        #{@indent}#{@compiled}
        }
      EOS
    end

    private

    ##
    # Processes a DOM node's descendents.
    #
    # * +base+ - Base Nokogiri node to start from.
    #
    def process(base)
      base.children.each do |node|
        next unless node.element? || node.text?

        dynamic_key = process_value(node.attr(DYNAMIC_KEY_ATTR), :attr)

        if node.text? || node.name == CONTENT_TAG || node.name == 'htx-text' || node.name == ':'
          if !node.text? && node.name != CONTENT_TAG
            warn("#{@name}:#{node.line}: The <#{node.name}> tag has been deprecated. Please use "\
              "<#{CONTENT_TAG}> for identical functionality.")
          end

          if (node.attributes.size - (dynamic_key ? 1 : 0)) != 0
            raise(MalformedTemplateError.new("<#{node.name}> tags may not have attributes other than "\
              "#{DYNAMIC_KEY_ATTR}", @name, node))
          end

          if (non_text_node = node.children.find { |n| !n.text? })
            raise(MalformedTemplateError.new("<#{node.name}> tags may not contain child tags", @name,
              non_text_node))
          end

          text = (node.text? ? node : node.children).text

          if (value = process_value(text))
            append(
              "#{indent(text[LEADING_WHITESPACE])}"\
              "htx.node(#{[
                value,
                dynamic_key,
                (@static_key += 1) << FLAG_BITS,
              ].compact.join(', ')})"\
              "#{indent(text[TRAILING_WHITESPACE])}"
            )
          else
            append(indent(text))
          end
        else
          childless = node.children.empty? || (node.children.size == 1 && node.children[0].text.strip == '')
          attrs, xmlns = process_attrs(node)

          append("htx.node(#{[
            "'#{tag_name(node.name)}'",
            attrs,
            dynamic_key,
            ((@static_key += 1) << FLAG_BITS) | ELEMENT | (childless ? CHILDLESS : 0) | (xmlns ? XMLNS : 0),
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
    # Appends a string to the compiled template function string with appropriate punctuation and/or
    # whitespace inserted.
    #
    # * +text+ - String to append to the compiled template string.
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
    # * +text+ - String of lines to indent.
    #
    def indent(text)
      return '' unless text

      text.gsub!(NEWLINE_NON_BLANK, "\n#{@indent}")
      text
    end

    ##
    # Processes, formats, and encodes an attribute or text node value. Returns nil if the value is
    # determined to be a control statement.
    #
    # * +text+ - String to process.
    # * +is_attr+ - Truthy if the text is an attribute value.
    #
    def process_value(text, is_attr = false)
      return nil if text.nil? || (!is_attr && text.strip == '')

      if (value = text[RAW_VALUE, 1])
        # Entire text is enclosed in ${...}.
        value.strip!
        quote = false
        escape_quotes = false
      elsif (value = text[TEMPLATE_STRING, 1])
        # Entire text is enclosed in backticks (template string).
        quote = true
        escape_quotes = false
      elsif is_attr || text.gsub(NON_CONTROL_STATEMENT, '') !~ CONTROL_STATEMENT
        # Text is an attribute value or doesn't match control statement pattern.
        value = text.dup
        quote = true
        escape_quotes = true
      else
        return nil
      end

      # Strip one leading and trailing newline (and attached spaces) and perform outdent. Outdent amount
      # calculation ignores everything before the first newline in its search for the least-indented line.
      outdent = value.scan(NON_BLANK_NON_FIRST_LINE).min
      value.gsub!(/#{LEADING_WHITESPACE}|#{TRAILING_WHITESPACE}|^#{outdent}/, '')
      value.gsub!(UNESCAPED_BACKTICK, '\1\\\`') if escape_quotes
      value.insert(0, '`').insert(-1, '`') if quote

      # Ensure any Unicode characters get converted to Unicode escape sequences. Also note that since
      # Nokogiri converts HTML entities to Unicode characters, this causes them to be properly passed to
      # `document.createTextNode` calls as Unicode escape sequences rather than (incorrectly) as HTML
      # entities.
      value.encode('ascii', fallback: ->(c) { "\\u#{c.ord.to_s(16).rjust(4, '0')}" })
    end

    ##
    # Processes a node's attributes, returning two items: a flat array of attribute names and values, and a
    # boolean indicating whether or not an xmlns attribute is present.
    #
    # Note: if the node is a <math> or <svg> tag without an explicit xmlns attribute set, an appropriate one
    # will be automatically added since it is required for those elements to render properly.
    #
    # * +node+ - Nokogiri node to process for attributes.
    #
    def process_attrs(node)
      attrs = []
      xmlns = !!node.attributes['xmlns']

      if !xmlns && DEFAULT_XMLNS[node.name]
        xmlns = true

        attrs << "'xmlns'"
        attrs << process_value(DEFAULT_XMLNS[node.name], :attr)
      end

      node.attributes.each do |_, attr|
        next if attr.name == DYNAMIC_KEY_ATTR

        attrs << "'#{attr_name(attr.name)}'"
        attrs << process_value(attr.value, :attr)
      end

      [attrs, xmlns]
    end

    ##
    # Returns the given text if the HTML5 parser is in use, or looks up the value in the tag map to get the
    # correctly-cased version, falling back to the supplied text if no mapping exists.
    #
    # * +text+ - Tag name as returned by Nokogiri parser.
    #
    def tag_name(text)
      self.class.html5_parser? ? text : (TAG_MAP[text] || text)
    end

    ##
    # Returns the given text if the HTML5 parser is in use, or looks up the value in the attribute map to
    # get the correctly-cased version, falling back to the supplied text if no mapping exists.
    #
    # * +text+ - Attribute name as returned by Nokogiri parser.
    #
    def attr_name(text)
      self.class.html5_parser? ? text : (ATTR_MAP[text] || text)
    end

    # The Nokogiri HTML parser downcases all tag and attribute names, but SVG tags and attributes are case
    # sensitive and often mix cased. These maps are used to restore the correct case of such tags and
    # attributes.
    #
    # Note: Nokogiri's newer HTML5 parser resulting from the Nokogumbo merge fixes this issue, but it is
    # currently not available for JRuby. It also does not parse <:> as a tag, which is why it's been
    # deprecated in favor of <htx-text>. Once support for <:> has been completely removed, the HTML5 parser
    # will be used for regular Ruby and this tag and attribute mapping hack reserved for JRuby (and any
    # other potential environments where the HTML5 parser is not available).

    # Source: https://developer.mozilla.org/en-US/docs/Web/SVG/Element
    TAG_MAP = %w[
      animateMotion animateTransform clipPath feBlend feColorMatrix feComponentTransfer feComposite
      feConvolveMatrix feDiffuseLighting feDisplacementMap feDistantLight feDropShadow feFlood feFuncA
      feFuncB feFuncG feFuncR feGaussianBlur feImage feMerge feMergeNode feMorphology feOffset fePointLight
      feSpecularLighting feSpotLight feTile feTurbulence foreignObject linearGradient radialGradient
      textPath
    ].map { |tag| [tag.downcase, tag] }.to_h.freeze

    # Source: https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute
    ATTR_MAP = %w[
      attributeName attributeType baseFrequency baseProfile calcMode clipPathUnits contentScriptType
      contentStyleType diffuseConstant edgeMode filterRes filterUnits glyphRef gradientTransform
      gradientUnits kernelMatrix kernelUnitLength keyPoints keySplines keyTimes lengthAdjust
      limitingConeAngle markerHeight markerUnits markerWidth maskContentUnits maskUnits numOctaves
      pathLength patternContentUnits patternTransform patternUnits pointsAtX pointsAtY pointsAtZ
      preserveAlpha preserveAspectRatio primitiveUnits refX refY referrerPolicy repeatCount repeatDur
      requiredExtensions requiredFeatures specularConstant specularExponent spreadMethod startOffset
      stdDeviation stitchTiles surfaceScale systemLanguage tableValues targetX targetY textLength viewBox
      viewTarget xChannelSelector yChannelSelector zoomAndPan
    ].map { |attr| [attr.downcase, attr] }.to_h.freeze
  end
end
