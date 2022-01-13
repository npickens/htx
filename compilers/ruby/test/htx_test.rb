# frozen_string_literal: true

require('htx')
require('minitest/autorun')
require_relative('test_helper')

class HTXTest < Minitest::Test
  include(TestHelper)

  # NOTE: More granular tests are forthcoming.

  context(HTX, '::compile') do
    test('raises an error when the template contains text at its root level') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX.compile('/template.htx', "<div>Hello</div> world!")
      end
    end

    test('raises an error when the template does not have a root element node') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX.compile('/template.htx', "\n  <!-- Hello -->\n")
      end
    end

    test('raises an error when the template has more than one root node') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX.compile('/template.htx', "<div></div><div></div>")
      end
    end

    test('raises an error if a dummy tag contains a child tag') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX.compile('/template.htx', "<:>Hello<b>!</b></:>")
      end
    end

    test('assigns compiled template function to a custom object when assign_to is specified') do
      template_name = '/components/for-custom-object.htx'
      template_content = '<div></div>'

      compiled = <<~EOS
        customObject['#{template_name}'] = function(htx) {
          htx.node('div', 5)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content, assign_to: 'customObject'))
    end

    test('treats tags with only whitespace text as childless') do
      template_name = '/components/whitespace-childless.htx'
      template_content = <<~EOS
        <div>
          <span>

          </span>
        </div>
      EOS

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
          htx.node('div', 4)
            htx.node('span', 9)
          htx.close()
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content))
    end

    test('compiles a template') do
      template_name = '/components/people.htx'
      template_content = <<~EOS
        <div class='people'>
          <h1>${this.title}</h1>

          <ul class='people-list'>
            for (let person of this.people) {
              <li class='person ${person.role}'>
                ${person.name}
              </li>
            }
          </ul>
        </div>
      EOS

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
          htx.node('div', 'class', `people`, 4)
            htx.node('h1', 8); htx.node(this.title, 14); htx.close()

            htx.node('ul', 'class', `people-list`, 16)
              for (let person of this.people) {
                htx.node('li', 'class', `person ${person.role}`, 20)
                  htx.node(person.name, 26)
                htx.close()
              }
          htx.close(2)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content))
    end
  end
end
