/**
 * HTXComponent
 * Copyright 2019 Nate Pickens
 *
 * @license MIT
 */
let HTXComponent = function() {
  let isMounting = false
  let mountQueue = []

  return class {
    constructor(htxPath) {
      this.htxPath = htxPath
    }

    render() {
      if (!this._isMounted && !isMounting) {
        throw('Cannot render unmounted component (call mount() instead of render()')
      }

      let initial = !this.node

      this.node = this.htx(this.node || this.htxPath)

      if (this.didRender) {
        if (this._isMounted) {
          this.didRender(initial)
        } else if (initial) {
          mountQueue.push(this)
        }
      }

      return this.node
    }

    mount(placementNode, placement = 'append') {
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

      mountQueue = []
    }

    htx(pathOrNode) {
      if (pathOrNode instanceof String && !window[pathOrNode]) throw `Template not found: ${pathOrNode}`

      return HTX.render(pathOrNode, this)
    }
  }
}()
