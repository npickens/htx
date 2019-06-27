# frozen_string_literal: true

require('nokogiri')

##
# A Ruby compiler for HTX templates.
#
class HTX
  VERSION = '0.0.0'

  CHILDLESS = 0b01
  TEXT_NODE = 0b10
  FLAG_BITS = 2

  DYNAMIC_KEY_ATTR = 'htx-key'

  LEADING_WHITESPACE = /\A *\n */.freeze
  TRAILING_WHITESPACE = /\n *\z/.freeze
  NON_BLANK_NON_FIRST_LINE = /(?<=\n) *(?=\S)/.freeze
  NEWLINE_NON_BLANK = /\n(?=[^\n]+)/.freeze

  END_STATEMENT_END = /(;|\n|\{|\}) *\z/.freeze
  BEGIN_STATEMENT_END = /\A *(;|\{|\n|\})/.freeze
  END_WHITESPACE = /\s\z/.freeze
  BEGIN_WHITESPACE = /\A\s/.freeze

  RAW_VALUE = /\A\s*\${([\S\s]*)}\s*\z/.freeze
  TEMPLATE_STRING = /\A\s*`([\S\s]*)`\s*\z/.freeze
  INTERPOLATION = /\$\\?{([^}]*})?/.freeze
  HTML_ENTITY = /&([a-zA-Z]+|#\d+|x[0-9a-fA-F]+);/.freeze
  NON_CONTROL_STATEMENT = /#{INTERPOLATION}|(#{HTML_ENTITY})/.freeze
  CONTROL_STATEMENT = /[{}();]/.freeze
  CLOSE_STATEMENT = /;?\s*htx\.close\((\d*)\);?(\s*)\z/.freeze

  ##
  # Compiles an HTX template and assigns it the given name (conventionally the path of the template file is
  # used, but it can be anything).
  #
  def self.compile(name, template)
    doc = Nokogiri::HTML::DocumentFragment.parse(template)
    js = ''.dup

    process(doc, js, static_key: 0)
    js.rstrip!

    <<~EOS
      window['#{name}'] = function(htx) {
        #{js}
      }
    EOS
  end

  ##
  # Processes a DOM node.
  #
  def self.process(base, js, options = {})
    base.children.each do |node|
      next if node.comment?

      dynamic_key = process_value(node.attr(DYNAMIC_KEY_ATTR), :attr)

      if node.text? || node.name == ':'
        text = (node.text? ? node : node.children).text

        if (value = process_value(text))
          append(js,
            "#{indent(text[LEADING_WHITESPACE])}"\
            "htx.node(#{[
              value,
              dynamic_key,
              ((options[:static_key] += 1) << FLAG_BITS) | TEXT_NODE,
            ].compact.join(', ')})"\
            "#{indent(text[TRAILING_WHITESPACE])}"
          )
        else
          append(js, indent(text))
        end
      else
        attrs = node.attributes.inject([]) do |attrs, (_, attr)|
          next attrs if attr.name == DYNAMIC_KEY_ATTR

          attrs << "'#{ATTR_MAP[attr.name] || attr.name}'"
          attrs << process_value(attr.value, :attr)
        end

        append(js, "htx.node(#{[
          "'#{TAG_MAP[node.name] || node.name}'",
          attrs,
          dynamic_key,
          ((options[:static_key] += 1) << FLAG_BITS) | (node.children.empty? ? CHILDLESS : 0),
        ].compact.flatten.join(', ')})")

        unless node.children.empty?
          process(node, js, options)

          count = ''
          js.sub!(CLOSE_STATEMENT) do
            count = $1 == '' ? 2 : $1.to_i + 1
            $2
          end

          append(js, "htx.close(#{count})")
        end
      end
    end
  end

  ##
  # Appends a string to the compiled template function string with appropriate punctuation and/or
  # whitespace inserted.
  #
  def self.append(js, text)
    if js == ''
      # Do nothing.
    elsif js !~ END_STATEMENT_END && text !~ BEGIN_STATEMENT_END
      js << '; '
    elsif js !~ END_WHITESPACE && text !~ BEGIN_WHITESPACE
      js << ' '
    elsif js[-1] == "\n"
      js << '  '
    end

    js << text
  end

  ##
  # Indents each line of a string (except the first).
  #
  def self.indent(text)
    return '' unless text

    text.gsub!(NEWLINE_NON_BLANK, "\n  ")
    text
  end

  ##
  # Processes, formats, and encodes an attribute or text node value. Returns nil if the value is determined
  # to be a control statement.
  #
  def self.process_value(text, is_attr = false)
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
    attributeName baseFrequency calcMode clipPathUnits diffuseConstant edgeMode filterUnits
    gradientTransform gradientUnits kernelMatrix kernelUnitLength keyPoints keySplines keyTimes lengthAdjust
    limitingConeAngle markerHeight markerUnits markerWidth maskContentUnits maskUnits numOctaves pathLength
    patternContentUnits patternTransform patternUnits pointsAtX pointsAtY pointsAtZ preserveAlpha
    preserveAspectRatio primitiveUnits refX refY repeatCount repeatDur requiredExtensions specularConstant
    specularExponent spreadMethod startOffset stdDeviation stitchTiles surfaceScale systemLanguage
    tableValues targetX targetY textLength viewBox xChannelSelector yChannelSelector zoomAndPan
  ].map { |attr| [attr.downcase, attr] }.to_h.freeze
end
