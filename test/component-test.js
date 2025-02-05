import * as Helpers from './test-helper.js';
import {after, assert, before, suite, test} from '@pmoo/testy';

suite('HTX.Component', () => {
  before(Helpers.setUpDOM)
  after(Helpers.tearDownDOM)

  test('mount defaults to appending to document.body', () => {
    new Helpers.HelloComponent().mount()

    assert.that(global.document.body.innerHTML).isEqualTo("<div>Hello, 'Verse!</div>")
  })

  test('mount defaults to appending to a node', () => {
    global.document.body.innerHTML = `
      <div id=container>
        <span id=child></span>
      </div>
    `

    const containerNode = document.querySelector('#container')
    const component = new Helpers.HelloComponent()

    component.mount(containerNode)

    assert.that(containerNode.lastChild).isEqualTo(component.node)
    assert.that(containerNode.lastChild.textContent).isEqualTo("Hello, 'Verse!")
  })

  test('mount defaults to document.body as the placement node', () => {
    global.document.body.innerHTML = '<div id=container></div>'

    const component = new Helpers.HelloComponent()

    component.mount('prepend')

    assert.that(document.body.firstChild).isEqualTo(component.node)
    assert.that(document.body.firstChild.textContent).isEqualTo("Hello, 'Verse!")
  })
})
