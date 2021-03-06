/**
 * HTXComponent
 * Copyright 2019-2021 Nate Pickens
 *
 * @license MIT
 */
let HTXComponent = function() {
  let isMounting
  let renderRoot
  let didRenders = []

  /**
   * Calls each `didRender` callback in the `didRenders` queue.
   */
  function runDidRenders() {
    for (let [component, initial] of didRenders) {
      component.didRender(initial)
    }

    renderRoot = null
    didRenders = []
  }

  return class {
    /**
     * Creates a new HTXComponent instance.
     *
     * @constructor
     * @param htxPath The path (name) of the compiled HTX template to use for this component.
     */
    constructor(htxPath) {
      this.htxPath = htxPath
    }

    /**
     * Creates the DOM fragment for this component if this is the first call; updates the existing DOM
     * otherwise. Calls `didRender` afterwards if it is defined.
     *
     * @return The root DOM node returned by the HTX template function.
     */
    render() {
      let initial = !this.node

      if (initial && !isMounting) {
        throw 'Cannot render unmounted component (call mount() instead of render())'
      }

      renderRoot = renderRoot || this
      this.node = HTX.render(this.node || this.htxPath, this)

      if (this.didRender) didRenders.push([this, initial])
      if (!isMounting && renderRoot == this) runDidRenders()

      return this.node
    }

    /**
     * Inserts this component's DOM fragment into another (usually the main document). Should only be called
     * once for initial rendering.
     *
     * @param placement The placement relative to placementNode (default is 'append'; can be 'prepend',
     *   'append', 'replace', 'before', or 'after').
     * @param placementNode The node this component is being placed relative to (default is document.body).
     */
    mount(...args) {
      isMounting = true

      let placement = args.find((a) => typeof a == 'string') || 'append'
      let placementNode = args.find((a) => typeof a != 'string') || document.body
      let node = this.render()

      placement == 'prepend' ? placementNode.prepend(node) :
      placement == 'append' ? placementNode.append(node) :
      placement == 'replace' ? placementNode.parentNode.replaceChild(node, placementNode) :
      placement == 'before' ? placementNode.parentNode.insertBefore(node, placementNode) :
      placement == 'after' ? placementNode.parentNode.insertBefore(node, placementNode.nextSibling) :
      node = null

      if (!node) throw `Unrecognized placement type: ${placement}`

      runDidRenders()
      isMounting = false
    }
  }
}()
