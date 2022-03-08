/**
 * HTXComponent is a wrapper for the main HTX library, designed to be extended by a child class and used to
 * manage a section of the DOM more cleanly than with the HTX library alone.
 */
let HTXComponent = function() {
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

  return class {
    /**
     * Creates a new HTXComponent instance.
     *
     * @constructor
     * @param htxPath Name or direct reference to a compiled HTX template function.
     */
    constructor(htxPath) {
      this.htx = new HTX(htxPath, this)
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
      this.node = htx.render()

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

      let placement = args.find((a) => typeof a == 'string') || 'append'
      let placementNode = args.find((a) => typeof a != 'string') || document.body

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
}()
