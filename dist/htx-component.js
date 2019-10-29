/**
 * HTXComponent
 * Copyright 2019 Nate Pickens
 *
 * @license MIT
 * @version 0.0.2
 */
let HTXComponent = function() {
  let isMounting = false
  let mountQueue = []

  return class {
    constructor(htxPath) {
      if (!window[htxPath]) throw `Template not found: ${htxPath}`

      this.htxPath = htxPath
    }

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

      mountQueue = []
    }
  }
}()
