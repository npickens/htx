import * as Helpers from './test-helper.js';
import {after, assert, before, suite, test} from '@pmoo/testy';

suite('HTX.Renderer', () => {
  before(Helpers.setUpDOM)
  after(Helpers.tearDownDOM)

  test('renders a basic element', () => {
    let template = new Helpers.HelloTemplate({})
    let node = template.render()

    assert.that(node.textContent).isEqualTo("Hello, 'Verse!")
  })

  test('updates an element', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('div', 9); $r.node(`Hello, ${this.name}!`, 16); $r.close()
    })

    let person = {name: 'Mal'}
    let template = new Template(person)
    let node = template.render()

    assert.that(node.textContent).isEqualTo('Hello, Mal!')

    person.name = 'Zoe'
    template.render()

    assert.that(node.textContent).isEqualTo('Hello, Zoe!')
  })
})
