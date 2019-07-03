class HTXTest < Minitest::Test
  # NOTE: More granular tests are forthcoming.

  def test_general
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
      window['/components/people.htx'] = function(htx) {
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

    assert_equal(HTX.compile(template_name, template_content), compiled)
  end
end
