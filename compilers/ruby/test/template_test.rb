# frozen_string_literal: true

require('htx')
require('minitest/autorun')
require_relative('test_helper')

class TemplateTest < Minitest::Test
  include(TestHelper)

  ##########################################################################################################
  ## General                                                                                              ##
  ##########################################################################################################

  test('compiles a template') do
    name = '/crew.htx'

    content = <<~HTML
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
    HTML

    render_body = <<~JS
      $renderer.node('div', 'class', `crew`, 9)
        $renderer.node('h1', 17); $renderer.node(this.title, 24); $renderer.close()

        $renderer.node('ul', 'class', `members`, 33)
          for (let member of this.members) {
            $renderer.node('li', 'class', `member ${member.role}`, 41)
              $renderer.node(member.name, 48)
            $renderer.close()
          }
      $renderer.close(2)
    JS

    template = HTX::Template.new(name, content)

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  test('assigns compiled template function to a custom object if assign_to: option is specified') do
    compiled = HTX::Template.new('/assign-to.htx', '<div></div>').compile(assign_to: 'customObject')
    expected = "customObject['/assign-to.htx'] = "

    assert_equal(expected, compiled[0, expected.size])
  end

  test('treats tags with only whitespace text as childless') do
    name = '/whitespace-childless.htx'

    content = <<~HTML
      <div>
        <span>

        </span>
      </div>
    HTML

    render_body = <<~JS
      $renderer.node('div', 9)
        $renderer.node('span', 19)
      $renderer.close()
    JS

    template = HTX::Template.new(name, content)

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  ##########################################################################################################
  ## Errors                                                                                               ##
  ##########################################################################################################

  test('raises an error if template contains non-whitespace text at root level') do
    args = ['/root-text.htx', '<div>Hello</div>, World!']

    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile }
    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile(as_module: true) }
  end

  test('raises an error if template does not have a root element') do
    args = '/root-missing.htx', "\n  <!-- Hello, World! -->\n"

    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile }
    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile(as_module: true) }
  end

  test('raises an error if template has more than one root element') do
    args = ['/root-multiple.htx', '<div></div><div></div>']

    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile }
    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile(as_module: true) }
  end

  test('raises an error if an unrecognized node type is encountered') do
    args = ['/unrecognized-node-type.htx', '<div><!-- Bad node --></div>']
    template = HTX::Template.new(*args)

    assert_raises(HTX::MalformedTemplateError) do
      template.stub(:preprocess, nil) { template.compile }
    end

    template = HTX::Template.new(*args)

    assert_raises(HTX::MalformedTemplateError) do
      template.stub(:preprocess, nil) { template.compile(as_module: true) }
    end
  end

  ##########################################################################################################
  ## Comments                                                                                             ##
  ##########################################################################################################

  test('removes comment nodes') do
    name = '/comment.htx'
    template = HTX::Template.new(name, '<div>Hello, <!-- Comment --> World!</div>')
    render_body = "$renderer.node('div', 9); $renderer.node(`Hello,  World!`, 16); $renderer.close()"

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  test('removes trailing newline of previous text node along with comment node') do
    name = '/comment-with-newline.htx'

    content = <<~HTML
      <div>
        Hello,
        <!-- Comment -->
        World!
      </div>
    HTML

    render_body = <<~JS
      $renderer.node('div', 9)
        $renderer.node(`Hello,
      World!`, 16)
      $renderer.close()
    JS

    template = HTX::Template.new(name, content)

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  ##########################################################################################################
  ## <htx-content>                                                                                        ##
  ##########################################################################################################

  test('compiles <htx-content> tag with no children to empty text node') do
    name = '/htx-content-empty.htx'
    template = HTX::Template.new(name, '<htx-content></htx-content>')
    render_body = '$renderer.node(``, 8)'

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  test('raises an error if <htx-content> tag contains a child tag') do
    args = ['/htx-content-child-tag.htx', '<htx-content>Hello, <b>World!</b></htx-content>']

    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile }
    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile(as_module: true) }
  end

  test('raises an error if <htx-content> tag has an attribute other than htx-key') do
    args = ['/htx-content-attribute.htx', '<htx-content class="bad"></htx-content>']

    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile }
    assert_raises(HTX::MalformedTemplateError) { HTX::Template.new(*args).compile(as_module: true) }
  end

  ##########################################################################################################
  ## <template>                                                                                           ##
  ##########################################################################################################

  test('compiles children of <template> tag but not the tag itself') do
    name = '/template-tag.htx'
    template = HTX::Template.new(name, '<table><template>if (true) { <tr></tr> }</template></table>')
    render_body = "$renderer.node('table', 9); if (true) {  $renderer.node('tr', 19) } $renderer.close()"

    Warning.stub(:warn, nil) do
      assert_assign_render_body(render_body, name, template)
      assert_module_render_body(render_body, name, template)
    end
  end

  test('warns when <template> tag is used') do
    name = '/template-tag.htx'
    template = HTX::Template.new(name, '<table><template>if (true) { <tr></tr> }</template></table>')
    render_body = "$renderer.node('table', 9); if (true) {  $renderer.node('tr', 19) } $renderer.close()"
    warning = nil

    Warning.stub(:warn, ->(msg, *) { warning = msg }) do
      assert_assign_render_body(render_body, name, template)
      assert_module_render_body(render_body, name, template)
    end

    assert(warning)
  end

  ##########################################################################################################
  ## Attributes - Case                                                                                    ##
  ##########################################################################################################

  test('maintains case of mixed-case SVG tag and attribute names') do
    name = '/case-sensitive-svg.htx'

    content = <<~HTML
      <svg xmlns='http://www.w3.org/2000/svg'>
        <clipPath clipPathUnits='userSpaceOnUse'></clipPath>
      </svg>
    HTML

    render_body = <<~JS
      $renderer.node('svg', 'xmlns', `http://www.w3.org/2000/svg`, 13)
        $renderer.node('clipPath', 'clipPathUnits', `userSpaceOnUse`, 23)
      $renderer.close()
    JS

    template = HTX::Template.new(name, content)

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  ##########################################################################################################
  ## Attributes - XMLNS                                                                                   ##
  ##########################################################################################################

  test('includes appropriate xmlns attribute if none is set on <math> and <svg> tags') do
    {
      'math' => 'http://www.w3.org/1998/Math/MathML',
      'svg' => 'http://www.w3.org/2000/svg',
    }.each do |tag, xmlns|
      name = "/#{tag}-missing-xmlns.htx"
      template = HTX::Template.new(name, "<#{tag}></#{tag}>")
      render_body = "$renderer.node('#{tag}', 'xmlns', `#{xmlns}`, 15)"

      assert_assign_render_body(render_body, name, template)
      assert_module_render_body(render_body, name, template)
    end
  end

  test('uses explicitly-set xmlns attribute if one is present') do
    %w[math svg].each do |tag|
      name = "/#{tag}-xmlns.htx"
      template = HTX::Template.new(name, "<#{tag} xmlns='explicit-xmlns'></#{tag}>")
      render_body = "$renderer.node('#{tag}', 'xmlns', `explicit-xmlns`, 15)"

      assert_assign_render_body(render_body, name, template)
      assert_module_render_body(render_body, name, template)
    end
  end

  ##########################################################################################################
  ## Attributes - Empty Value                                                                             ##
  ##########################################################################################################

  test('uses empty string for an attribute with no value') do
    name = '/empty-attribute-value.htx'
    template = HTX::Template.new(name, '<div empty-attr></div>')
    render_body = "$renderer.node('div', 'empty-attr', ``, 11)"

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  ##########################################################################################################
  ## Indentation                                                                                          ##
  ##########################################################################################################

  test('indents with two spaces if template has no indentation') do
    name = '/indent.htx'
    template = HTX::Template.new(name, '<div>Hello, World!</div>')
    render_body = "$renderer.node('div', 9); $renderer.node(`Hello, World!`, 16); $renderer.close()"

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  test('indents with leading space(s) of first indented line') do
    name = '/indent.htx'

    content = <<~HTML
      <div>
         Hello,
          <b>World!</b>
      </div>
    HTML

    render_body = <<~JS
      $renderer.node('div', 9)
         $renderer.node(`Hello,`, 16)
          $renderer.node('b', 25); $renderer.node(`World!`, 32)
      $renderer.close(2)
    JS

    template = HTX::Template.new(name, content)

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  test('indents with leading tab(s) of first indented line') do
    name = '/tab-indent.htx'

    content = <<~HTML
      <div>
      \tHello,
      \t\t<b>World!</b>
      </div>
    HTML

    render_body = <<~JS
      $renderer.node('div', 9)
      \t$renderer.node(`Hello,`, 16)
      \t\t$renderer.node('b', 25); $renderer.node(`World!`, 32)
      $renderer.close(2)
    JS

    template = HTX::Template.new(name, content)

    assert_assign_render_body(render_body, name, template)
    assert_module_render_body(render_body, name, template)
  end

  ##########################################################################################################
  ## #inspect                                                                                             ##
  ##########################################################################################################

  test('#inspect returns a high-level object info string') do
    template = HTX::Template.new('/inspect.htx', '<div>Hello, World!</div>')
    template.compile

    assert_inspect('#<HTX::Template ' \
      '@as_module=false, ' \
      '@assign_to="globalThis", ' \
      '@base_indent="  ", ' \
      '@compiled="globalThis[\'/inspect.htx\'] = ((HTX) => { [...]", ' \
      '@content="<div>Hello, World!</div>", ' \
      '@import_path="/htx/htx.js", ' \
      '@name="/inspect.htx"' \
    '>', template)
  end

  ##########################################################################################################
  ## Helpers                                                                                              ##
  ##########################################################################################################

  def assert_assign_render_body(render_body, name, template)
    assert_equal(compiled(name, render_body), template.compile)
  end

  def assert_module_render_body(render_body, name, template)
    assert_equal(compiled(name, render_body, as_module: true), template.compile(as_module: true))
  end

  def compiled(name, render_body, as_module: false, import_path: '/htx/htx.js', assign_to: 'globalThis')
    indent = render_body[/^[^\S\n]+/] || '  '
    render_body = render_body.gsub(
      /^[^\S\n]+[^\s]|(?<=\n)[^\n]+\Z/,
      "#{as_module ? indent : indent * 2}\\0"
    ) << (render_body[-1] == "\n" ? '' : "\n")

    if as_module
      <<~JS
        import * as HTX from '#{import_path}'

        function render($renderer) {
        #{indent}#{render_body}
        #{indent}return $renderer.rootNode
        }

        export function Template(context) {
        #{indent}this.render = render.bind(context, new HTX.Renderer)
        }
      JS
    else
      <<~JS
        #{assign_to}['#{name}'] = ((HTX) => {
        #{indent}function render($renderer) {
        #{indent * 2}#{render_body}
        #{indent * 2}return $renderer.rootNode
        #{indent}}

        #{indent}return function Template(context) {
        #{indent}#{indent}this.render = render.bind(context, new HTX.Renderer)
        #{indent}}
        })(globalThis.HTX ||= {});
      JS
    end
  end
end
