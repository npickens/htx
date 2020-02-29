/**
 * HTXComponent
 * Copyright 2019-2020 Nate Pickens
 *
 * @license MIT
 */
let HTXComponent = function() {
  let isMounting = false
  let mountQueue = []

  return class {
    /**
     * Creates a new HTXComponent instance.
     *
     * @constructor
     */
    constructor(htxPath) {
      if (!window[htxPath]) throw `Template not found: ${htxPath}`

      this.htxPath = htxPath
    }

    /**
     * Creates the DOM fragment for this component if this is the first call; updates the existing DOM
     * otherwise. Calls `didRender` afterwards if it is defined.
     *
     * @return The root DOM node returned by the HTX template function.
     */
    render() {
      if (!this._isMounted && !isMounting) {
        throw('Cannot render unmounted component (call mount() instead of render())')
      }

      let initial = !this.node

      this.node = HTX.render(this.node || this.htxPath, this)

      if (this.didRender) {
        if (this._isMounted) {
          this.didRender(initial)
        } else if (initial) {
          mountQueue.push(this)
        }
      }

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
      let placement = args.find((a) => typeof a == 'string') || 'append'
      let placementNode = args.find((a) => typeof a != 'string') || document.body

      isMounting = true
      mountQueue = []

      this.render()

      switch (placement) {
        case 'prepend': placementNode.prepend(this.node); break
        case 'append': placementNode.append(this.node); break
        case 'replace': placementNode.parentNode.replaceChild(this.node, placementNode); break
        case 'before': placementNode.parentNode.insertBefore(this.node, placementNode); break
        case 'after': placementNode.parentNode.insertBefore(this.node, placementNode.nextSibling); break
        default: throw `Unrecognized placement type: ${placement}`
      }

      for (let component of mountQueue) {
        component._isMounted = true
        component.didRender(true)
      }

      isMounting = false
      mountQueue = []
    }
  }
}()
