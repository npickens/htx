/**
 * HTXComponent
 * Copyright 2019-2022 Nate Pickens
 *
 * @license MIT
 * @version 0.0.6
 */
let HTXComponent = function() {
  let isMounting
  let renderRoot
  let didRenders = []

  function runDidRenders() {
    for (let [component, initial] of didRenders) {
      component.didRender(initial)
    }

    renderRoot = null
    didRenders = []
  }

  return class {
    constructor(htxPath) {
      this.htxPath = htxPath
    }

    render() {
      let initial = !this.node

      if (initial && !isMounting && !renderRoot) {
        throw 'Cannot render unmounted component (call mount() instead of render())'
      }

      renderRoot = renderRoot || this
      this.node = HTX.render(this.node || this.htxPath, this)

      if (this.didRender) didRenders.push([this, initial])
      if (!isMounting && renderRoot == this) runDidRenders()

      return this.node
    }

    mount(...args) {
      isMounting = true

      let placement = args.find((a) => typeof a == 'string') || 'append'
      let placementNode = args.find((a) => typeof a != 'string') || document.body
      let render = this.render.bind(this)

      placement == 'prepend' ? placementNode.prepend(render()) :
      placement == 'append' ? placementNode.append(render()) :
      placement == 'replace' ? placementNode.parentNode.replaceChild(render(), placementNode) :
      placement == 'before' ? placementNode.parentNode.insertBefore(render(), placementNode) :
      placement == 'after' ? placementNode.parentNode.insertBefore(render(), placementNode.nextSibling) :
      render = null

      if (!render) throw `Unrecognized placement type: ${placement}`

      runDidRenders()
      isMounting = false
    }
  }
}()
