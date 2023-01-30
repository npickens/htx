# frozen_string_literal: true

require('htx')
require('minitest/autorun')
require_relative('test_helper')

class HTXTest < Minitest::Test
  include(TestHelper)

  ##########################################################################################################
  ## General                                                                                              ##
  ##########################################################################################################

  context(HTX::Template, '#compile') do
    test('compiles a template') do
      name = '/crew.htx'
      uncompiled = <<~EOS
        <div class='crew'>
          <h1>${this.title}</h1>

          <ul class='members'>
            for (let member of this.members) {
              <li class='member ${member.role}'>
                ${member.name}
              </li>
            }
          </ul>
        </div>
      EOS

      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node('div', 'class', `crew`, 9)
            htx.node('h1', 17); htx.node(this.title, 24); htx.close()

            htx.node('ul', 'class', `members`, 33)
              for (let member of this.members) {
                htx.node('li', 'class', `member ${member.role}`, 41)
                  htx.node(member.name, 48)
                htx.close()
              }
          htx.close(2)
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, uncompiled).compile)
    end

    test('assigns compiled template function to a custom object if assign_to option is specified') do
      name = '/assign-to.htx'
      uncompiled = '<div></div>'
      compiled = <<~EOS
        customObject['#{name}'] = function(htx) {
          htx.node('div', 11)
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, uncompiled).compile(assign_to: 'customObject'))
    end

    test('treats tags with only whitespace text as childless') do
      name = '/whitespace-childless.htx'
      uncompiled = <<~EOS
        <div>
          <span>

          </span>
        </div>
      EOS

      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node('div', 9)
            htx.node('span', 19)
          htx.close()
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, uncompiled).compile)
    end
  end

  ##########################################################################################################
  ## Errors                                                                                               ##
  ##########################################################################################################

  context(HTX::Template, '#compile', 'raises an error') do
    test('if template contains non-whitespace text at root level') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX::Template.new('/root-text.htx', '<div>Hello</div>, World!').compile
      end
    end

    test('if template does not have a root element') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX::Template.new('/root-missing.htx', "\n  <!-- Hello, World! -->\n").compile
      end
    end

    test('if template has more than one root element') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX::Template.new('/root-multiple.htx', '<div></div><div></div>').compile
      end
    end

    test('if an unrecognized node type is encountered') do
      template = HTX::Template.new('/unrecognized-node-type.htx', '<div><!-- Bad node --></div>')

      assert_raises(HTX::MalformedTemplateError) do
        template.stub(:preprocess, nil) { template.compile }
      end
    end
  end

  ##########################################################################################################
  ## Comments                                                                                             ##
  ##########################################################################################################

  context(HTX::Template, '#compile') do
    test('removes comment nodes') do
      name = '/comment.htx'
      uncompiled = <<~EOS
        <div>Hello, <!-- Comment --> World!</div>
      EOS

      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node('div', 9); htx.node(`Hello,  World!`, 16); htx.close()
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, uncompiled).compile)
    end

    test('removes trailing newline of previous text node along with comment node') do
      name = '/comment-with-newline.htx'
      uncompiled = <<~EOS
        <div>
          Hello,
          <!-- Comment -->
          World!
        </div>
      EOS

      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node('div', 9)
            htx.node(`Hello,
        World!`, 16)
          htx.close()
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, uncompiled).compile)
    end
  end

  ##########################################################################################################
  ## <htx-content>                                                                                        ##
  ##########################################################################################################

  context(HTX::Template, '#compile') do
    test('compiles <htx-content> tag with no children to empty text node') do
      name = '/htx-content-empty.htx'
      uncompiled = '<htx-content></htx-content>'
      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node(``, 8)
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, uncompiled).compile)
    end

    test('if <htx-content> tag contains a child tag') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX::Template.new(
          '/htx-content-child-tag.htx',
          '<htx-content>Hello, <b>World!</b></htx-content>'
        ).compile
      end
    end

    test('if <htx-content> tag has an attribute other than htx-key') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX::Template.new('/htx-content-attribute.htx', '<htx-content class="bad"></htx-content>').compile
      end
    end
  end

  ##########################################################################################################
  ## Attributes - Case                                                                                    ##
  ##########################################################################################################

  context(HTX::Template, '#compile') do
    test('maintains case of mixed-case SVG tag and attribute names when non-HTML5 parser is used') do
      name = '/case-sensitive-svg.htx'

      content = <<~EOS
        <svg xmlns='http://www.w3.org/2000/svg'>
          <clipPath clipPathUnits='userSpaceOnUse'></clipPath>
        </svg>
      EOS

      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node('svg', 'xmlns', `http://www.w3.org/2000/svg`, 13)
            htx.node('clipPath', 'clipPathUnits', `userSpaceOnUse`, 23)
          htx.close()
        }
      EOS

      HTX::Template.stub(:html5_parser?, false) do
        assert_equal(compiled, HTX::Template.new(name, content).compile)
      end
    end
  end

  ##########################################################################################################
  ## Attributes - XMLNS                                                                                   ##
  ##########################################################################################################

  context(HTX::Template, '#compile') do
    test('includes appropriate xmlns attribute if none is set on <math> and <svg> tags') do
      {
        'math' => 'http://www.w3.org/1998/Math/MathML',
        'svg' => 'http://www.w3.org/2000/svg',
      }.each do |tag, xmlns|
        name = "/#{tag}-missing-xmlns.htx"
        content = "<#{tag}></#{tag}>"
        compiled = <<~EOS
          globalThis['#{name}'] = function(htx) {
            htx.node('#{tag}', 'xmlns', `#{xmlns}`, 15)
          }
        EOS

        assert_equal(compiled, HTX::Template.new(name, content).compile)
      end
    end

    test('uses explicitly-set xmlns attribute if one is present') do
      %w[math svg].each do |tag|
        name = "/#{tag}-xmlns.htx"
        content = "<#{tag} xmlns='explicit-xmlns'></#{tag}>"
        compiled = <<~EOS
          globalThis['#{name}'] = function(htx) {
            htx.node('#{tag}', 'xmlns', `explicit-xmlns`, 15)
          }
        EOS

        assert_equal(compiled, HTX::Template.new(name, content).compile)
      end
    end
  end

  ##########################################################################################################
  ## Attributes - Empty Value                                                                             ##
  ##########################################################################################################

  context(HTX::Template, '#compile') do
    test('uses empty string for an attribute with no value') do
      name = '/empty-attribute-value.htx'
      content = "<div empty-attr></div>"
      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node('div', 'empty-attr', ``, 11)
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, content).compile)
    end
  end

  ##########################################################################################################
  ## Indentation                                                                                          ##
  ##########################################################################################################

  context(HTX::Template, '#compile') do
    test('indents with two spaces if template has no indentation') do
      name = '/indent.htx'
      content = "<div>Hello, World!</div>"
      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
          htx.node('div', 9); htx.node(`Hello, World!`, 16); htx.close()
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, content).compile)
    end

    test('indents with leading space(s) of first indented line') do
      name = '/indent.htx'
      content = <<~EOS
        <div>
           Hello,
            <b>World!</b>
        </div>
      EOS

      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
           htx.node('div', 9)
              htx.node(`Hello,`, 16)
               htx.node('b', 25); htx.node(`World!`, 32)
           htx.close(2)
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, content).compile)
    end

    test('indents with leading tab(s) of first indented line') do
      name = '/tab-indent.htx'
      content = <<~EOS
        <div>
        \tHello,
        \t\t<b>World!</b>
        </div>
      EOS

      compiled = <<~EOS
        globalThis['#{name}'] = function(htx) {
        \thtx.node('div', 9)
        \t\thtx.node(`Hello,`, 16)
        \t\t\thtx.node('b', 25); htx.node(`World!`, 32)
        \thtx.close(2)
        }
      EOS

      assert_equal(compiled, HTX::Template.new(name, content).compile)
    end
  end
end
