class HTXTest < Minitest::Test
  describe('HTX.compile') do
    it('properly formats output of tab-indented templates') do
      template_name = '/tab-indent.htx'
      template_content = <<~EOS
        <div>
        \tHello
        \t<b>World!</b>
        </div>
      EOS

      compiled = <<~EOS
        window['#{template_name}'] = function(htx) {
          htx.node('div', 4)
          \thtx.node(`Hello`, 10)
          \thtx.node('b', 12); htx.node(`World!`, 18)
          htx.close(2)
        }
      EOS

      assert_equal(compiled, HTX.compile(template_name, template_content))
    end
  end
end
