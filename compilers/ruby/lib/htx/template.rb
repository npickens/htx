# frozen_string_literal: true

require('nokogiri')

module HTX
  class Template
    ELEMENT   = 1 << 0
    CHILDLESS = 1 << 1
    XMLNS     = 1 << 2
    FLAG_BITS = 3

    INDENT_DEFAULT = '  '
    CONTENT_TAG = 'htx-content'
    DYNAMIC_KEY_ATTR = 'htx-key'
    DEFAULT_XMLNS = {
      'math' => 'http://www.w3.org/1998/Math/MathML',
      'svg' => 'http://www.w3.org/2000/svg',
    }.freeze

    INDENT_GUESS = /^( +|\t+)(?=\S)/.freeze
    INDENT_REGEX = /\n(?=[^\n])/.freeze

    NO_SEMICOLON_BEGIN = /\A\s*[\n;}]/.freeze
    NO_SEMICOLON_END = /(\A|[\n;{}][^\S\n]*)\z/.freeze

    NEWLINE_BEGIN = /\A\s*\n/.freeze
    NEWLINE_END = /\n[^\S\n]*\z/.freeze
    NEWLINE_END_OPTIONAL = /\n?[^\S\n]*\z/.freeze

    WHITESPACE_BEGIN = /\A\s/.freeze
    NON_WHITESPACE = /\S/.freeze

    ##
    # Returns true if Nokogiri's HTML5 parser is available.
    #
    def self.html5_parser?
      defined?(Nokogiri::HTML5)
    end

    ##
    # Returns Nokogiri's HTML5 parser if available or Nokogiri's default HTML (4) parser otherwise.
    #
    def self.nokogiri_parser
      html5_parser? ? Nokogiri::HTML5 : Nokogiri::HTML
    end

    ##
    # Creates a new instance.
    #
    # * +name+ - Template name. Conventionally the path of the template file.
    # * +content+ - Template content.
    #
    def initialize(name, content)
      @name = name
      @content = content
    end

    ##
    # Compiles the HTX template.
    #
    # * +assign_to+ - JavaScript object to assign the template function to (default: +globalThis+).
    #
    def compile(assign_to: nil)
      @assign_to = assign_to || 'globalThis'
      @base_indent = @indent = @content[INDENT_GUESS] || INDENT_DEFAULT
      @static_key = 0
      @close_count = 0
      @whitespace_buff = nil
      @statement_buff = +''
      @compiled = +''

      doc = self.class.nokogiri_parser.fragment(@content)
      preprocess(doc)
      process(doc)

      @compiled
    end

    private

    ##
    # Removes comment nodes and merges any adjoining text nodes that result from such removals.
    #
    # * +node+ - Nokogiri node to preprocess.
    #
    def preprocess(node)
      if node.text?
        if node.parent&.fragment? && node.blank?
          node.remove
        elsif (prev_node = node.previous)&.text?
          prev_node.content += node.content
          node.remove
        end
      elsif node.comment?
        if node.previous&.text? && node.next&.text? && node.next.content.match?(NEWLINE_BEGIN)
          content = node.previous.content.sub!(NEWLINE_END_OPTIONAL, '')
          content.empty? ? node.previous.remove : node.previous.content = content
        end

        node.remove
      end

      node.children.each do |child|
        preprocess(child)
      end

      if node.fragment?
        children = node.children
        root, root2 = children[0..1]

        if (child = children.find(&:text?))
          raise(MalformedTemplateError.new('text nodes are not allowed at root level', @name, child))
        elsif !root
          raise(MalformedTemplateError.new('a root node is required', @name))
        elsif root2
          raise(MalformedTemplateError.new("root node already defined on line #{root.line}", @name, root2))
        end
      end
    end

    ##
    # Processes a DOM node's descendents.
    #
    # * +node+ - Nokogiri node to process.
    #
    def process(node, xmlns: false)
      if node.fragment?
        process_fragment_node(node)
      elsif node.element?
        process_element_node(node, xmlns: xmlns)
      elsif node.text?
        process_text_node(node)
      else
        raise(MalformedTemplateError.new("unrecognized node type #{node.class}", @name, node))
      end
    end

    ##
    # Processes a document fragment node.
    #
    # * +node+ - Nokogiri node to process.
    #
    def process_fragment_node(node)
      append(
        <<~JS
          #{@assign_to}['#{@name}'] = ((HTX) => {
          #{@indent}function render($rndr) {
        JS
      )

      @indent = @base_indent * 2

      node.children.each do |child|
        process(child)
      end

      append("\n\n#{@indent}return $rndr.rootNode")

      @indent = @base_indent

      append(
        +<<~JS

          #{@indent}}

          #{@indent}return function Template(context) {
          #{@indent * 2}this.render = render.bind(context, new HTX.Renderer)
          #{@indent}}
          })(globalThis.HTX ||= {});
        JS
      )

      flush
    end

    ##
    # Processes an element node.
    #
    # * +node+ - Nokogiri node to process.
    # * +xmlns+ - True if node is the descendant of a node with an xmlns attribute.
    #
    def process_element_node(node, xmlns: false)
      children = node.children
      childless = children.empty? || (children.size == 1 && self.class.formatting_node?(children.first))
      dynamic_key = self.class.attribute_value(node.attr(DYNAMIC_KEY_ATTR))
      attributes = self.class.process_attributes(node, xmlns: xmlns)
      xmlns ||= !!self.class.namespace(node)

      if self.class.htx_content_node?(node)
        if attributes.size > 0
          raise(MalformedTemplateError.new("<#{node.name}> tags may not have attributes other than "\
            "#{DYNAMIC_KEY_ATTR}", @name, node))
        elsif (child = children.find { |n| !n.text? })
          raise(MalformedTemplateError.new("<#{node.name}> tags may not contain child tags", @name, child))
        end

        process_text_node(
          children.first || Nokogiri::XML::Text.new('', node.document),
          dynamic_key: dynamic_key,
        )
      else
        append_htx_node(
          "'#{self.class.tag_name(node.name)}'",
          *attributes,
          dynamic_key,
          ELEMENT | (childless ? CHILDLESS : 0) | (xmlns ? XMLNS : 0),
        )

        unless childless
          children.each do |child|
            process(child, xmlns: xmlns)
          end

          @close_count += 1
        end
      end
    end

    ##
    # Processes a text node.
    #
    # * +node+ - Nokogiri node to process.
    # * +dynamic_key+ - Dynamic key of the parent if it's an <htx-content> node.
    #
    def process_text_node(node, dynamic_key: nil)
      content = node.content

      if node.blank?
        if !content.include?("\n")
          append_htx_node("`#{content}`")
        elsif node.next
          append(content)
        else
          @whitespace_buff = content[NEWLINE_END]
        end
      else
        htx_content_node = self.class.htx_content_node?(node.parent)
        parser = TextParser.new(content, statement_allowed: !htx_content_node)
        parser.parse

        append(parser.leading) unless htx_content_node

        if parser.statement?
          append(indent(parser.content))
        elsif parser.raw?
          append_htx_node(indent(parser.content), dynamic_key)
        else
          append_htx_node(parser.content, dynamic_key)
        end

        unless htx_content_node
          append(parser.trailing)
          @whitespace_buff = parser.whitespace_buff
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
      return if text.nil? || text.empty?

      if @close_count > 0
        close_count = @close_count
        @close_count = 0

        append("$rndr.close(#{close_count unless close_count == 1})")
      end

      if @whitespace_buff
        @statement_buff << @whitespace_buff
        @whitespace_buff = nil
        confirmed_newline = true
      end

      if (confirmed_newline || @statement_buff.match?(NEWLINE_END)) && !text.match?(NEWLINE_BEGIN)
        @statement_buff << @indent
      elsif !@statement_buff.match?(NO_SEMICOLON_END) && !text.match?(NO_SEMICOLON_BEGIN)
        @statement_buff << ";#{' ' unless text.match?(WHITESPACE_BEGIN)}"
      end

      flush if text.match?(NON_WHITESPACE)
      @statement_buff << text
    end

    ##
    # Appends an +htx.node+ call to the compiled template function string.
    #
    # * +args+ - Arguments to use for the +htx.node+ call (any +nil+ ones are removed).
    #
    def append_htx_node(*args)
      return if args.first.nil?

      args.compact!
      args << 0 unless args.last.kind_of?(Integer)
      args[-1] |= (@static_key += 1) << FLAG_BITS

      append("$rndr.node(#{args.join(', ')})")
    end

    ##
    # Flushes statement buffer.
    #
    def flush
      @compiled << @statement_buff
      @statement_buff.clear
    end

    ##
    # Indents each line of a string (except the first).
    #
    # * +text+ - String of lines to indent.
    #
    def indent(text)
      text.gsub!(INDENT_REGEX, "\\0#{@indent}")
      text
    end

    ##
    # Returns true if the node is whitespace containing at least one newline.
    #
    # * +node+ - Nokogiri node to check.
    #
    def self.formatting_node?(node)
      node.blank? && node.content.include?("\n")
    end

    ##
    # Returns true if the node is an <htx-content> node (or one of its now-deprecated names).
    #
    # * +node+ - Nokogiri node to check.
    #
    def self.htx_content_node?(node)
      node&.name == CONTENT_TAG
    end

    ##
    # Processes a node's attributes returning a flat array of attribute names and values.
    #
    # * +node+ - Nokogiri node to process the attributes of.
    #
    def self.process_attributes(node, xmlns:)
      attributes = []

      if !xmlns && !node.attribute('xmlns') && (xmlns = namespace(node))
        attributes.push(
          attribute_name('xmlns'),
          attribute_value(xmlns)
        )
      end

      node.attribute_nodes.each.with_object(attributes) do |attribute, attributes|
        next if attribute.node_name == DYNAMIC_KEY_ATTR

        attributes.push(
          attribute_name(attribute.node_name),
          attribute_value(attribute.value)
        )
      end
    end

    ##
    # Returns namespace URL of a Nokogiri node.
    #
    # * +node+ - Nokogiri node to get the namespace of.
    #
    def self.namespace(node)
      node.namespace&.href || DEFAULT_XMLNS[node.name]
    end

    ##
    # Returns the given text if the HTML5 parser is in use, or looks up the value in the tag map to get the
    # correctly-cased version, falling back to the supplied text if no mapping exists.
    #
    # * +text+ - Tag name as returned by Nokogiri.
    #
    def self.tag_name(text)
      html5_parser? ? text : (TAG_MAP[text] || text)
    end

    ##
    # Returns the given text if the HTML5 parser is in use, or looks up the value in the attribute map to
    # get the correctly-cased version, falling back to the supplied text if no mapping exists.
    #
    # * +text+ - Attribute name as returned by Nokogiri.
    #
    def self.attribute_name(text)
      "'#{html5_parser? ? text : (ATTR_MAP[text] || text)}'"
    end

    ##
    # Returns the processed value of an attribute.
    #
    # * +text+ - Attribute value as returned by Nokogiri.
    #
    def self.attribute_value(text)
      text ? TextParser.new(text, statement_allowed: false).parse : nil
    end

    # The Nokogiri::HTML5 parser is used whenever possible, which correctly handles mix-cased SVG tag and
    # attribute names. But when falling back to the Nokogiri::HTML parser (e.g. in JRuby environments where
    # Nokogiri::HTML5 is not available), all tag and attribute names get downcased. These maps are used to
    # restore the correct case.

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
