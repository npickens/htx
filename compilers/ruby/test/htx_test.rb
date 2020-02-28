class HTXTest < Minitest::Test
  # NOTE: More granular tests are forthcoming.

  describe('HTX.compile') do
    it('raises an error when the template contains text at its root level') do
      -> { HTX.compile('/template.htx', "<div>Hello</div> world!") }.must_raise(HTX::MalformedTemplateError)
    end

    it('raises an error when the template does not have a root element node') do
      -> { HTX.compile('/template.htx', "\n  <!-- Hello -->\n") }.must_raise(HTX::MalformedTemplateError)
    end

    it('raises an error when the template has more than one root node') do
      -> { HTX.compile('/template.htx', "<div></div><div></div>") }.must_raise(HTX::MalformedTemplateError)
    end

    it('compiles a template') do
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

      HTX.compile(template_name, template_content).must_equal(compiled)
    end
  end
end
