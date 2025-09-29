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

  test('sets <input> Node object `value` property in addition to calling setAttribute', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('input', 'value', this.value, 11)
    })

    let context = {value: 'Hello'}
    let template = new Template(context)
    let node = template.render()

    context.value = 'World'
    template.render()

    assert.that(node.getAttribute('value')).isEqualTo('World')
    assert.that(node.value).isEqualTo('World')
  })

  test('sets <input> Node object `checked` property in addition to calling setAttribute', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('input', 'checked', this.checked, 11)
    })

    let context = {checked: false}
    let template = new Template(context)
    let node = template.render()

    context.checked = true
    template.render()

    assert.that(node.getAttribute('checked')).isEqualTo('')
    assert.that(node.checked).isTrue()
  })

  test('sets <option> Node object `selected` property in addition to calling setAttribute', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('select', 9)
        $r.node('option', 17); $r.node(`Option 1`, 24); $r.close()
        $r.node('option', 'selected', this.selected, 33); $r.node(`Option 2`, 40)
      $r.close(2)
    })

    let context = {selected: false}
    let template = new Template(context)
    let node = template.render().lastChild

    context.selected = true
    template.render()

    assert.that(node.getAttribute('selected')).isEqualTo('')
    assert.that(node.selected).isTrue()
  })

  test('treats undefined, null, and false values as false and all other values as true for <input> ' +
       '`checked` and <option> `selected` attributes', () => {
    let Template = Helpers.defineTemplate(function($r) {
      $r.node('div', 9)
        $r.node('input', 'checked', this.checked, 19)
        $r.node('select', 25)
          $r.node('option', 33); $r.node(`Option 1`, 40); $r.close()
          $r.node('option', 'selected', this.selected, 49); $r.node(`Option 2`, 56)
      $r.close(3)
    })

    let context = {}
    let template = new Template(context)
    let node = template.render()
    let input = node.querySelector('input')
    let option = node.querySelector('option:last-child')

    let setValue = function(value) {
      context.checked = value
      context.selected = value

      template.render()
    }

    setValue(undefined)
    assert.isNull(input.getAttribute('checked'))
    assert.isNull(option.getAttribute('selected'))
    assert.isFalse(input.checked)
    assert.isFalse(option.selected)

    setValue(null)
    assert.isNull(input.getAttribute('checked'))
    assert.isNull(option.getAttribute('selected'))
    assert.isFalse(input.checked)
    assert.isFalse(option.selected)

    setValue(false)
    assert.isNull(input.getAttribute('checked'))
    assert.isNull(option.getAttribute('selected'))
    assert.isFalse(input.checked)
    assert.isFalse(option.selected)

    setValue(NaN)
    assert.that(input.getAttribute('checked')).isEqualTo('')
    assert.that(option.getAttribute('selected')).isEqualTo('')
    assert.isTrue(input.checked)
    assert.isTrue(option.selected)

    setValue(0)
    assert.that(input.getAttribute('checked')).isEqualTo('')
    assert.that(option.getAttribute('selected')).isEqualTo('')
    assert.isTrue(input.checked)
    assert.isTrue(option.selected)

    setValue('')
    assert.that(input.getAttribute('checked')).isEqualTo('')
    assert.that(option.getAttribute('selected')).isEqualTo('')
    assert.isTrue(input.checked)
    assert.isTrue(option.selected)

    setValue('false')
    assert.that(input.getAttribute('checked')).isEqualTo('')
    assert.that(option.getAttribute('selected')).isEqualTo('')
    assert.isTrue(input.checked)
    assert.isTrue(option.selected)
  })
})
