/**********************************************************************************************************/
/* HTX Component                                                                                          */
/**********************************************************************************************************/

class HTXComponent {
  constructor(htxPath) {
    this.htxPath = htxPath
  }

  render() {
    if (!this.isMounted && !HTXComponent.isMounting) {
      throw('Cannot render unmounted component (hint: call mount() instead of render()')
    }

    let initial = !this.el

    this.el = this.htx(this.htxPath, this.el)

    if (this.didRender) {
      if (this.isMounted) {
        this.didRender(initial)
      } else if (initial) {
        HTXComponent.mountQueue.push(this)
      }
    }

    return this.el
  }

  mount(placementNode, placement = 'append') {
    HTXComponent.isMounting = true
    HTXComponent.mountQueue = []

    this.render()

    switch (placement) {
      case 'prepend': placementNode.prepend(this.el); break
      case 'append': placementNode.append(this.el); break
      case 'replace': placementNode.parentNode.replaceChild(this.el, placementNode); break
      case 'before': placementNode.parentNode.insertBefore(this.el, placementNode); break
      case 'after': placementNode.parentNode.insertBefore(this.el, placementNode.nextSibling); break
      default: throw `Unrecognized placement type: ${placement}`
    }

    for (let component of HTXComponent.mountQueue) {
      component.isMounted = true
      component.didRender(true)
    }

    HTXComponent.mountQueue = []
  }

  htx(path, node) {
    if (!window[path]) throw `Template not found: ${path}`

    return window[path].call(this, node)
  }
}
