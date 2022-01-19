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

    test('raises an error if a text node tag contains a child tag') do
      assert_raises(HTX::MalformedTemplateError) do
        HTX.compile('/template.htx', "<htx-text>Hello<b>!</b></htx-text>")
      end
    end

    test('assigns compiled template function to a custom object when assign_to is specified') do
      template_name = '/components/for-custom-object.htx'
      template_content = '<div></div>'

      compiled = <<~EOS
        customObject['#{template_name}'] = function(htx) {
          htx.node('div', 9)
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
          htx.node('div', 8)
            htx.node('span', 17)
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
          htx.node('div', 'class', `people`, 8)
            htx.node('h1', 16); htx.node(this.title, 26); htx.close()

            htx.node('ul', 'class', `people-list`, 32)
              for (let person of this.people) {
                htx.node('li', 'class', `person ${person.role}`, 40)
                  htx.node(person.name, 50)
                htx.close()
              }
          htx.close(2)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content))
    end

    test('adds appropriate xmlns attribute if none is set on <math> and <svg> tags') do
      {
        'math' => 'http://www.w3.org/1998/Math/MathML',
        'svg' => 'http://www.w3.org/2000/svg',
      }.each do |tag, xmlns|
        template1_name = "/components/#{tag}1.htx"
        template1_content = "<#{tag}></#{tag}>"
        compiled1 = <<~EOS
          window['#{template1_name}'] = function(htx) {
            htx.node('#{tag}', 'xmlns', `#{xmlns}`, 13)
          }
        EOS

        template2_name = "/components/#{tag}2.htx"
        template2_content = "<#{tag} class='hello'></#{tag}>"
        compiled2 = <<~EOS
          window['#{template2_name}'] = function(htx) {
            htx.node('#{tag}', 'xmlns', `#{xmlns}`, 'class', `hello`, 13)
          }
        EOS

        assert_equal(compiled1, HTX.compile(template1_name, template1_content))
        assert_equal(compiled2, HTX.compile(template2_name, template2_content))
      end
    end

    test('does not modify xmlns attribute when one is set on <math> and <svg> tags') do
      %w[math svg].each do |tag|
        template1_name = "/components/#{tag}1.htx"
        template1_content = "<#{tag} xmlns='custom-xmlns'></#{tag}>"
        compiled1 = <<~EOS
          window['#{template1_name}'] = function(htx) {
            htx.node('#{tag}', 'xmlns', `custom-xmlns`, 13)
          }
        EOS

        template2_name = "/components/#{tag}2.htx"
        template2_content = "<#{tag} class='hello' xmlns='custom-xmlns'></#{tag}>"
        compiled2 = <<~EOS
          window['#{template2_name}'] = function(htx) {
            htx.node('#{tag}', 'class', `hello`, 'xmlns', `custom-xmlns`, 13)
          }
        EOS

        assert_equal(compiled1, HTX.compile(template1_name, template1_content))
        assert_equal(compiled2, HTX.compile(template2_name, template2_content))
      end
    end
  end
end
