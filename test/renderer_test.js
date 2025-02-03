import {after, assert, before, suite, test} from '@pmoo/testy';
import {JSDOM} from 'jsdom';
import {Renderer} from '../src/renderer.js';

suite('HTX.Renderer', () => {
  /********************************************************************************************************/
  /* Tests                                                                                                */
  /********************************************************************************************************/

  test('renders a basic element', () => {
    let Template = defineTemplate(function($r) {
      $r.node('div', 9); $r.node(`Hello, 'Verse!`, 16); $r.close()
    })

    let template = new Template({})
    let node = template.render()

    assert.that(node.textContent).isEqualTo("Hello, 'Verse!")
  })

  test('updates an element', () => {
    let Template = defineTemplate(function($r) {
      $r.node('div', 9); $r.node(`Hello, ${this.name}!`, 16); $r.close()
    })

    let context = {name: 'Mal'}
    let template = new Template(context)
    let node = template.render()

    assert.that(node.textContent).isEqualTo('Hello, Mal!')

    context.name = 'Zoe'
    template.render()

    assert.that(node.textContent).isEqualTo('Hello, Zoe!')
  })

  /********************************************************************************************************/
  /* Hooks                                                                                                */
  /********************************************************************************************************/

  before(() => {
    const dom = new JSDOM(`<!DOCTYPE html><html><head></head><body></body></html>`)

    global.window = dom.window
    global.document = dom.window.document
    global.Node = dom.window.Node
  })

  after(() => {
    delete global.window
    delete global.document
    delete global.Node
  })

  /********************************************************************************************************/
  /* Helpers                                                                                              */
  /********************************************************************************************************/

  function defineTemplate(renderBody) {
    function render($r) {
      renderBody.call(this, $r)

      return $r.rootNode
    }

    return function Template(context) {
      this.render = render.bind(context, new Renderer)
    }
  }
})
