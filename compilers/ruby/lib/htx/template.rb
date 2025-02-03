# frozen_string_literal: true

require('nokogiri')

module HTX
  # Represents an HTX template and provides functionality for compiling a raw / human-written template into
  # its compiled / pure JavaScript form.
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

    AUTO_SEMICOLON_BEGIN = /\A\s*[\n;}]/.freeze
    AUTO_SEMICOLON_END = /(\A|[\n;{}][^\S\n]*)\z/.freeze

    NEWLINE_BEGIN = /\A\s*\n/.freeze
    NEWLINE_END = /\n[^\S\n]*\z/.freeze
    NEWLINE_END_OPTIONAL = /\n?[^\S\n]*\z/.freeze

    WHITESPACE_BEGIN = /\A\s/.freeze
    NON_WHITESPACE = /\S/.freeze

    # Public: Return a boolean indicating if Nokogiri's HTML5 parser is available. (In some environments,
    # such as JRuby, the HTML5 parser is not available, in which case the older / less strict HTML4 parser
    # must be used instead.)
    def self.html5_parser?
      !!defined?(Nokogiri::HTML5)
    end

    # Public: Get Nokogiri's HTML5 parser if available or Nokogiri's default HTML4 parser otherwise.
    #
    # Returns the best available Nokogiri parser.
    def self.nokogiri_parser
      html5_parser? ? Nokogiri::HTML5 : Nokogiri::HTML
    end

    # Public: Create a new instance.
    #
    # name    - String template name. Conventionally the path of the template file.
    # content - String template body/content.
    #
    # Examples
    #
    #   HTX::Template.new('/components/crew.htx', '<div>...</div>')
    #   HTX::Template.new(File.basename(path), File.read(path))
    def initialize(name, content)
      @name = name
      @content = content
    end

    # Public: Compile the template to its JavaScript form.
    #
    # as_module:   - Boolean indicating whether or not to compile as a JavaScript module (defaults to
    #                HTX.as_module).
    # import_path: - String path to the HTX JavaScript library for the module import statement (defaults to
    #                HTX.import_path; ignored when as_module: false).
    # assign_to:   - String JavaScript object to assign the template function to (defaults to
    #                HTX.assign_to; ignored when as_module: true).
    #
    # Examples
    #
    #   template = HTX::Template.new('/components/crew.htx', '<div>...</div>')
    #   template.compile(as_module: true, import_path: '/vendor/htx.js')
    #   # => "import * as HTX from '/vendor/htx.js' [...]"
    #
    #   template = HTX::Template.new('/components/crew.htx', '<div>...</div>')
    #   template.compile(as_module: false, assign_to: 'myTemplates')
    #   # => "myTemplates['/components/crew.htx'] = [...]"
    #
    # Returns the compiled template String (JavaScript code).
    def compile(as_module: nil, import_path: nil, assign_to: nil)
      @as_module = as_module.nil? ? HTX.as_module : as_module
      @import_path = import_path || HTX.import_path
      @assign_to = assign_to || HTX.assign_to
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

    # Public: Get a high-level object info String about this Template instance.
    #
    # Returns the String.
    def inspect
      "#<#{self.class} " \
        "@as_module=#{@as_module.inspect}, " \
        "@assign_to=#{@assign_to.inspect}, " \
        "@base_indent=#{@base_indent.inspect}, " \
        "@compiled=#{@compiled&.sub(/\n[\s\S]+/, ' [...]').inspect}, " \
        "@content=#{@content&.sub(/\n[\s\S]+/, ' [...]').inspect}, " \
        "@import_path=#{@import_path.inspect}, " \
        "@name=#{@name.inspect}" \
      '>'
    end

    private

    # Internal: Remove comment nodes and merge any adjoining text nodes that result from such removals.
    #
    # node - Nokogiri::XML::Node node to preprocess.
    #
    # Returns nothing.
    # Raises HTX::MalformedTemplateError if a text node is found at the root level.
    # Raises HTX::MalformedTemplateError if no root node is found.
    # Raises HTX::MalformedTemplateError if multiple root nodes are found.
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

    # Internal: Process a DOM node's descendants.
    #
    # node   - Nokogiri::XML::Node node to process.
    # xmlns: - Boolean indicating if the node has an XML namespace.
    #
    # Returns nothing.
    # Raises HTX::MalformedTemplateError if the node is not a fragment, element, or text node.
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

    # Internal: Process a document fragment node.
    #
    # node - Nokogiri::XML::DocumentFragment node to process.
    #
    # Returns nothing.
    def process_fragment_node(node)
      append("#{
        if @as_module
          "import * as HTX from '#{@import_path}'\n\n"
        else
          "#{@assign_to}['#{@name}'] = ((HTX) => {\n#{@indent}"
        end
      }function render($renderer) {\n")

      @indent = @base_indent * 2 unless @as_module

      node.children.each do |child|
        process(child)
      end

      append("\n\n#{@indent}return $renderer.rootNode")

      @indent = @as_module ? '' : @base_indent

      append(
        <<~JS

          #{@indent}}

          #{@indent}#{@as_module ? 'export' : 'return'} function Template(context) {
          #{@indent}#{@base_indent}this.render = render.bind(context, new HTX.Renderer)
          #{@indent}}#{
          "\n})(globalThis.HTX ||= {});" unless @as_module}
        JS
      )

      flush
    end

    # Internal: Process an element node.
    #
    # node   - Nokogiri::XML::Element node to process.
    # xmlns: - Boolean indicating if the node has an inherited XML namespace from an ancestor.
    #
    # Returns nothing.
    # Raises HTX::MalformedTemplateError if the element is an <htx-content> tag and has attribute(s) other
    #   than htx-key or a non-text child/children.
    def process_element_node(node, xmlns: false)
      is_template = node.name == 'template'
      children = node.children
      childless = children.empty? || (children.size == 1 && formatting_node?(children.first))
      dynamic_key = attribute_value(node.attr(DYNAMIC_KEY_ATTR))
      attributes = process_attributes(node, xmlns: xmlns)
      xmlns ||= !namespace(node).nil?

      if htx_content_node?(node)
        if !attributes.empty?
          message = "<#{node.name}> tags may not have attributes other than #{DYNAMIC_KEY_ATTR}"
          raise(MalformedTemplateError.new(message, @name, node))
        elsif (non_text_child = children.find { |n| !n.text? })
          message = "<#{node.name}> tags may not contain child tags"
          raise(MalformedTemplateError.new(message, @name, non_text_child))
        end

        process_text_node(
          children.first || Nokogiri::XML::Text.new('', node.document),
          dynamic_key: dynamic_key,
        )
      else
        unless is_template
          append_htx_node(
            "'#{tag_name(node.name)}'",
            *attributes,
            dynamic_key,
            ELEMENT | (childless ? CHILDLESS : 0) | (xmlns ? XMLNS : 0),
          )
        end

        unless childless
          children.each do |child|
            process(child, xmlns: xmlns)
          end

          @close_count += 1 unless is_template
        end
      end
    end

    # Internal: Process a text node.
    #
    # node        - Nokogiri::XML::Text node to process.
    # dynamic_key: - String dynamic key of the node's parent if the parent is an <htx-content> node (since
    #                an <htx-content> node is replaced with its child text node during compilation).
    #
    # Returns nothing.
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
        htx_content_node = htx_content_node?(node.parent)
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

    # Internal: Append a string to the compiled template function string with appropriate punctuation and/or
    # whitespace inserted.
    #
    # text - String to append to the compiled template string.
    #
    # Returns nothing.
    def append(text)
      return if text.nil? || text.empty?

      if @close_count > 0
        close_count = @close_count
        @close_count = 0

        append("$renderer.close(#{close_count unless close_count == 1})")
      end

      if @whitespace_buff
        @statement_buff << @whitespace_buff
        @whitespace_buff = nil
        confirmed_newline = true
      end

      if (confirmed_newline || @statement_buff.match?(NEWLINE_END)) && !text.match?(NEWLINE_BEGIN)
        @statement_buff << @indent
      else
        unless @statement_buff.match?(AUTO_SEMICOLON_END) || text.match?(AUTO_SEMICOLON_BEGIN)
          @statement_buff << ';'
        end

        unless @statement_buff.empty? || text.match?(WHITESPACE_BEGIN)
          @statement_buff << ' '
        end
      end

      flush if text.match?(NON_WHITESPACE)
      @statement_buff << text
    end

    # Internal: Append a $renderer.node call to the compiled template function string.
    #
    # args - Array of String text or tag name, String attribute names and values, and an Integer bitwise
    #        flag value to use for the $renderer.node call (any nil items are ignored).
    #
    # Returns nothing.
    def append_htx_node(*args)
      return if args.first.nil?

      args.compact!
      args << 0 unless args.last.kind_of?(Integer)
      args[-1] |= (@static_key += 1) << FLAG_BITS

      append("$renderer.node(#{args.join(', ')})")
    end

    # Internal: Flush the statement buffer.
    #
    # Returns nothing.
    def flush
      @compiled << @statement_buff
      @statement_buff.clear
    end

    # Internal: Indent each line of a string except the first.
    #
    # text - String of lines to indent.
    #
    # Returns the String indented text.
    def indent(text)
      text.gsub!(INDENT_REGEX, "\\0#{@indent}")
      text
    end

    # Internal: Determine if the node is all whitespace while also containing at least one newline.
    #
    # node - Nokogiri::XML::Node node to check.
    #
    # Returns the boolean result.
    def formatting_node?(node)
      node.blank? && node.content.include?("\n")
    end

    # Internal: Determine if the node is an <htx-content> tag.
    #
    # node - Nokogiri::XML::Node node to check.
    #
    # Returns the boolean result.
    def htx_content_node?(node)
      node&.name == CONTENT_TAG
    end

    # Internal: Process a node's attributes.
    #
    # node - Nokogiri::XML::Node node to process the attributes of.
    #
    # Returns an Array of String attribute names and values (['k1', 'v1', 'k2', 'v2', ...]).
    def process_attributes(node, xmlns:)
      attributes = []

      if !xmlns && !node.attribute('xmlns') && (xmlns = namespace(node))
        attributes.push(
          attribute_name('xmlns'),
          attribute_value(xmlns)
        )
      end

      node.attribute_nodes.each do |attribute|
        next if attribute.node_name == DYNAMIC_KEY_ATTR

        attributes.push(
          attribute_name(attribute.node_name),
          attribute_value(attribute.value)
        )
      end

      attributes
    end

    # Internal: Get the namespace URL of a node.
    #
    # node - Nokogiri::XML::Node node to get the namespace of.
    #
    # Returns the namespace URL String.
    def namespace(node)
      node.namespace&.href || DEFAULT_XMLNS[node.name]
    end

    # Internal: Restore appropriate casing of a tag name if needed. When Nokogiri's HTML4 parser is being
    # used, all tag names get downcased, which breaks case-sensitive SVG elements and must be corrected.
    #
    # text - String tag name as returned by Nokogiri.
    #
    # Returns the properly-cased String tag name.
    def tag_name(text)
      self.class.html5_parser? ? text : (TAG_MAP[text] || text)
    end

    # Internal: Restore appropriate casing of an attribute name if needed. When Nokogiri's HTML4 parser is
    # being used, all attribute names get downcased, which breaks case-sensitive SVG attributes and must be
    # corrected.
    #
    # text - String attribute name as returned by Nokogiri.
    #
    # Returns the properly-cased String attribute name.
    def attribute_name(text)
      "'#{self.class.html5_parser? ? text : (ATTR_MAP[text] || text)}'"
    end

    # Internal: Parse an attribute value to properly handle JavaScript interpolations.
    #
    # text - String attribute value as returned by Nokogiri.
    #
    # Returns the String processed value.
    def attribute_value(text)
      text ? TextParser.new(text, statement_allowed: false).parse : nil
    end

    # The Nokogiri::HTML5 parser is used whenever possible, which correctly handles mix-cased SVG tag and
    # attribute names. But when falling back to the Nokogiri::HTML parser (e.g. in JRuby environments where
    # Nokogiri::HTML5 is not available), all tag and attribute names get downcased. These maps are used to
    # restore the correct case.

    # Source: https://developer.mozilla.org/en-US/docs/Web/SVG/Element
    TAG_MAP = %w[
      animateMotion
      animateTransform
      clipPath
      feBlend
      feColorMatrix
      feComponentTransfer
      feComposite
      feConvolveMatrix
      feDiffuseLighting
      feDisplacementMap
      feDistantLight
      feDropShadow
      feFlood
      feFuncA
      feFuncB
      feFuncG
      feFuncR
      feGaussianBlur
      feImage
      feMerge
      feMergeNode
      feMorphology
      feOffset
      fePointLight
      feSpecularLighting
      feSpotLight
      feTile
      feTurbulence
      foreignObject
      glyphRef
      linearGradient
      radialGradient
      textPath
    ].to_h { |tag| [tag.downcase, tag] }.freeze

    # Source: https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute
    ATTR_MAP = %w[
      allowReorder
      attributeName
      attributeType
      autoReverse
      baseFrequency
      baseProfile
      calcMode
      clipPathUnits
      contentScriptType
      contentStyleType
      diffuseConstant
      edgeMode
      externalResourcesRequired
      filterRes
      filterUnits
      glyphRef
      gradientTransform
      gradientUnits
      kernelMatrix
      kernelUnitLength
      keyPoints
      keySplines
      keyTimes
      lengthAdjust
      limitingConeAngle
      markerHeight
      markerUnits
      markerWidth
      maskContentUnits
      maskUnits
      numOctaves
      pathLength
      patternContentUnits
      patternTransform
      patternUnits
      pointsAtX
      pointsAtY
      pointsAtZ
      preserveAlpha
      preserveAspectRatio
      primitiveUnits
      refX
      refY
      referrerPolicy
      repeatCount
      repeatDur
      requiredExtensions
      requiredFeatures
      specularConstant
      specularExponent
      spreadMethod
      startOffset
      stdDeviation
      stitchTiles
      surfaceScale
      systemLanguage
      tableValues
      targetX
      targetY
      textLength
      viewBox
      viewTarget
      xChannelSelector
      yChannelSelector
      zoomAndPan
    ].to_h { |attr| [attr.downcase, attr] }.freeze
  end
end
