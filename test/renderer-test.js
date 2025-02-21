import * as Helpers from './test-helper.js';
import {after, assert, before, fail, suite, test} from '@pmoo/testy';

suite('HTX.Renderer', () => {
  before(Helpers.setUpDOM)
  after(Helpers.tearDownDOM)

  /********************************************************************************************************/
  /* General                                                                                              */
  /********************************************************************************************************/

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

  test('renders undefined and null as empty text', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('div', 9); $r.node(this.content, 16); $r.close()
    })

    assert.that(new Template({content: undefined}).render().textContent).isEqualTo('')
    assert.that(new Template({content: null}).render().textContent).isEqualTo('')
  })

  /********************************************************************************************************/
  /* Attributes                                                                                           */
  /********************************************************************************************************/

  test('sets <input> Node object `value` property instead of calling setAttribute', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('input', 'value', this.value, 11)
    })

    let context = {value: 'Hello'}
    let template = new Template(context)
    let node = template.render()

    node.setAttribute = () => fail.with('Expected setAttribute to not be called')
    context.value = 'World'
    template.render()

    assert.that(node.value).isEqualTo('World')
  })

  test('sets <input> Node object `checked` property instead of calling setAttribute', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('input', 'checked', this.checked, 11)
    })

    let context = {checked: false}
    let template = new Template(context)
    let node = template.render()

    node.setAttribute = () => fail.with('Expected setAttribute to not be called')
    context.checked = true
    template.render()

    assert.that(node.checked).isTrue()
  })

  test('sets <option> Node object `selected` property instead of calling setAttribute', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('select', 9)
        $r.node('option', 17); $r.node(`Option 1`, 24); $r.close()
        $r.node('option', 'selected', this.selected, 33); $r.node(`Option 2`, 40)
      $r.close(2)
    })

    let context = {selected: false}
    let template = new Template(context)
    let node = template.render().lastChild

    node.setAttribute = () => fail.with('Expected setAttribute to not be called')
    context.selected = true
    template.render()

    assert.that(node.selected).isTrue()
  })
})
