# frozen_string_literal: true

require('htx')
require('minitest/autorun')
require_relative('test_helper')

class HTXIndentationTest < Minitest::Test
  include(TestHelper)

  context(HTX, '::compile') do
    test('properly formats output of tab-indented templates') do
      template_name = '/tab-indent.htx'
      template_content = <<~EOS
        <div>
        \tHello
        \t<b>World!</b>
        </div>
      EOS

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
        \thtx.node('div', 4)
        \t\thtx.node(`Hello`, 10)
        \t\thtx.node('b', 12); htx.node(`World!`, 18)
        \thtx.close(2)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content))
    end

    test('indents by default amount if :indent option is not provided and template has no indentation') do
      template_name = '/indent.htx'
      template_content = "<div>Hello</div>"

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
          htx.node('div', 4); htx.node(`Hello`, 10); htx.close()
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content))
    end

    test('indents by first indented line\'s whitespace if :indent option is not supplied') do
      template_name = '/indent.htx'
      template_content = <<~EOS
        <div>
           Hello
            <b>World!</b>
        </div>
      EOS

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
           htx.node('div', 4)
              htx.node(`Hello`, 10)
               htx.node('b', 12); htx.node(`World!`, 18)
           htx.close(2)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content))
    end

    test('indents by specified number spaces if :indent option is numeric') do
      template_name = '/indent.htx'
      template_content = <<~EOS
        <div>
          Hello
          <b>World!</b>
        </div>
      EOS

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
             htx.node('div', 4)
               htx.node(`Hello`, 10)
               htx.node('b', 12); htx.node(`World!`, 18)
             htx.close(2)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content, indent: 5))
    end

    test('indents with :indent option if it is a string') do
      template_name = '/indent.htx'
      template_content = <<~EOS
        <div>
          Hello
          <b>World!</b>
        </div>
      EOS

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
        \thtx.node('div', 4)
        \t  htx.node(`Hello`, 10)
        \t  htx.node('b', 12); htx.node(`World!`, 18)
        \thtx.close(2)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content, indent: "\t"))
    end

    test('raises error if :indent option is a string containing characters other than spaces and tabs') do
      assert_raises do
        HTX.compile('/template.htx', '<div></div>', indent: " \t>")
      end
    end
  end
end
