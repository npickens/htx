import * as HTX from '../src/htx.js';
import {JSDOM} from 'jsdom';

export function setUpDOM() {
  const dom = new JSDOM(`<!DOCTYPE html><html><head></head><body></body></html>`)

  global.window = dom.window
  global.document = dom.window.document
  global.Node = dom.window.Node
}

export function tearDownDOM() {
  delete global.window
  delete global.document
  delete global.Node
}

export function defineTemplate(renderBody) {
  function render($r) {
    renderBody.call(this, $r)

    return $r.rootNode
  }

  return function Template(context) {
    this.render = render.bind(context, new HTX.Renderer)
  }
}

export function defineComponent(template, ...functions) {
  const klass = class extends HTX.Component {
    constructor() {
      super(template)
    }
  }

  for (const func of functions) {
    klass.prototype[func.name] = func
  }

  return klass
}

export const HelloTemplate = defineTemplate(function($r) {
  $r.node('div', 9); $r.node(`Hello, 'Verse!`, 16); $r.close()
})

export const HelloComponent = defineComponent(HelloTemplate)
