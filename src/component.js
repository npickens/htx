import * as HTX from 'renderer.js'

let isMounting
let renderRoot
let didRenders = []

/**
 * Calls each `didRender` callback in the `didRenders` queue.
 */
function runDidRenders() {
  renderRoot = null

  while (didRenders.length) {
    let [component, initial] = didRenders.shift()
    component.didRender(initial)
  }
}

/**
 * Component is a lightweight wrapper for the main Renderer class, designed to be extended by a child class.
 * It provides a few conveniences not offered by raw templates, such as a function `mount` for mounting to
 * the main DOM and the option to implement a `didRender` callback which will be called whenever a render
 * occurs.
 */
export class Component {
  /**
   * Creates a new HTXComponent instance.
   *
   * @constructor
   * @param template HTX template function.
   */
  constructor(template) {
    if (typeof template == 'string') {
      console.warn('[DEPRECATED] Passing a template name to the HTX.Component constructor is deprecated: ' +
        'pass a direct template function reference instead')
    }

    this.template = HTX.Renderer.templateResolver(template, this, true)
  }

  /**
   * Creates the DOM fragment for this component if this is the first call; updates the existing DOM
   * otherwise. Calls `didRender` afterwards if it is defined.
   *
   * @return Root DOM node returned by the HTX template function.
   */
  render() {
    let initial = !this.node

    if (initial && !isMounting && !renderRoot) {
      throw 'Cannot render unmounted component (call mount() instead of render())'
    }

    renderRoot = renderRoot || this
    this.node = this.template.render()

    if (this.didRender) didRenders.push([this, initial])
    if (!isMounting && renderRoot == this) runDidRenders()

    return this.node
  }

  /**
   * Inserts this component's DOM fragment into another (usually the main document). Should only be called
   * once for initial rendering.
   *
   * @param placement Placement relative to placementNode (default is 'append'; can be 'prepend',
   *   'append', 'replace', 'before', or 'after').
   * @param placementNode Node this component is being placed relative to (default is `document.body`).
   */
  mount(...args) {
    isMounting = true

    let placement = args.find(a => typeof a == 'string') || 'append'
    let placementNode = args.find(a => typeof a != 'string') || document.body

    if (placement == 'append' || placement == 'prepend' || placement == 'before' ||
      placement == 'after' || placement == 'replace') {
      placementNode[placement.replace('replace', 'replaceWith')](this.render())
    } else {
      throw `Unrecognized placement type: ${placement}`
    }

    isMounting = false
    runDidRenders()
  }
}
