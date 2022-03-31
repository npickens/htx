/**
 * HTXComponent
 * Copyright 2019-2022 Nate Pickens
 *
 * @license MIT
 * @version 0.0.9
 */
let HTXComponent = function() {
  let isMounting
  let renderRoot
  let didRenders = []

  function runDidRenders() {
    renderRoot = null

    while (didRenders.length) {
      let [component, initial] = didRenders.shift()
      component.didRender(initial)
    }
  }

  return class {
    constructor(htxPath) {
      this.htx = new HTX(htxPath, this)
    }

    render() {
      let initial = !this.node

      if (initial && !isMounting && !renderRoot) {
        throw 'Cannot render unmounted component (call mount() instead of render())'
      }

      renderRoot = renderRoot || this
      this.node = this.htx.render()

      if (this.didRender) didRenders.push([this, initial])
      if (!isMounting && renderRoot == this) runDidRenders()

      return this.node
    }

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
