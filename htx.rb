require('nokogiri')

class HTX
  NO_FLAGS = 0
  CHILDLESS = 1
  TEXT = 2

  DYNAMIC_KEY_ATTR = 'htx-key'

  RAW_VALUE = /^(`?)\${(.*)}\1$/.freeze
  TEMPLATE_STRING = /^`.*`$/.freeze
  CONTROL_STATEMENT = /[{}();]/.freeze

  INTERPOLATIONS = /\$\\?{([^}]*})?/.freeze
  INTERPOLATION = /\${(.*)}/.freeze
  INTERPOLATION_ESCAPED = /\$\\{/.freeze

  NEWLINE_WHITESPACE = /\s*\n\s*/.freeze
  MULTIPLE_SPACES = /\s{2,}/.freeze

  EXTRACT_CLOSE_COUNT = /htx\.close\((\d*)\)/.freeze

  def self.compile(name, htx)
    doc = Nokogiri::HTML::DocumentFragment.parse(htx) { |c| c.noblanks }
    js = []

    process(doc, js, static_key: 0)

    <<~EOS
      window['#{name}'] = function(node) {
      let htx = node ? node.__htx__ : new HTX()
      #{js.join("\n")}
      return htx.rootNode
      }
    EOS
  end

  def self.process(base, js, options = {})
    base.children.each do |node|
      text = node.text.strip
      dynamic_key = process_value(node.attr(DYNAMIC_KEY_ATTR), :attr) || 'null'

      if node.comment? || (node.text? && text == '')
        # Skip.
      elsif node.text? || node.name == ':'
        if (value = process_value(text))
          js << "htx.node(#{value}, #{options[:static_key] += 1}, #{dynamic_key}, #{CHILDLESS | TEXT})"
        else
          js << text.gsub(NEWLINE_WHITESPACE, "\n")
        end
      else
        attrs = node.attributes.inject([]) do |attrs, (_, attr)|
          next attrs if attr.name == DYNAMIC_KEY_ATTR

          attrs << "'#{ATTR_MAP[attr.name] || attr.name}'"
          attrs << process_value(attr.value, :attr)
        end

        js << "htx.node(#{[
          "'#{TAG_MAP[node.name] || node.name}'",
          options[:static_key] += 1,
          dynamic_key,
          node.children.empty? ? CHILDLESS : NO_FLAGS,
          (attrs.join(', ') unless attrs.empty?),
        ].compact.join(', ')})"

        unless node.children.empty?
          process(node, js, options)

          if (count = js.last[EXTRACT_CLOSE_COUNT, 1])
            js[-1] = "htx.close(#{count == '' ? 2 : count.to_i + 1})"
          else
            js << 'htx.close()'
          end
        end
      end
    end
  end

  def self.process_value(str, is_attr = false)
    return nil unless str

    str.gsub!(NEWLINE_WHITESPACE, ' ')
    str.gsub!(MULTIPLE_SPACES, ' ')

    if (value = str[RAW_VALUE, 2])
      value
    elsif str =~ TEMPLATE_STRING
      str
    elsif !is_attr && str.gsub(INTERPOLATIONS, '') =~ CONTROL_STATEMENT
      nil
    elsif str =~ INTERPOLATION
      "`#{str}`"
    else
      "'#{str.gsub("'", "\\\\'").gsub(INTERPOLATION_ESCAPED, '${')}'"
    end
  end

  # The Nokogiri HTML parser downcases all tag and attribute names, but SVG tags and attributes are case
  # sensitive and often mix cased. These maps are used to restore the correct case of such tags and
  # attributes.
  TAG_MAP = Hash[*%w[
    animateMotion animateTransform clipPath feBlend feColorMatrix feComponentTransfer feComposite
    feConvolveMatrix feDiffuseLighting feDisplacementMap feDistantLight feDropShadow feFlood feFuncA feFuncB
    feFuncG feFuncR feGaussianBlur feImage feMerge feMergeNode feMorphology feOffset fePointLight
    feSpecularLighting feSpotLight feTile feTurbulence foreignObject linearGradient radialGradient textPath
  ].map { |k| [k.downcase, k] }.flatten].freeze

  ATTR_MAP = Hash[*%w[
    attributeName baseFrequency calcMode clipPathUnits diffuseConstant edgeMode filterUnits
    gradientTransform gradientUnits kernelMatrix kernelUnitLength keyPoints keySplines keyTimes lengthAdjust
    limitingConeAngle markerHeight markerUnits markerWidth maskContentUnits maskUnits numOctaves pathLength
    patternContentUnits patternTransform patternUnits pointsAtX pointsAtY pointsAtZ preserveAlpha
    preserveAspectRatio primitiveUnits refX refY repeatCount repeatDur requiredExtensions specularConstant
    specularExponent spreadMethod startOffset stdDeviation stitchTiles surfaceScale systemLanguage
    tableValues targetX targetY textLength viewBox xChannelSelector yChannelSelector zoomAndPan
  ].map { |k| [k.downcase, k] }.flatten].freeze
end
