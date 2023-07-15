/**
 * HTX.Component
 * Copyright 2019-2023 Nate Pickens
 *
 * @license MIT
 * @version 0.1.1
 */
(HTX => {
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

  class Component {
    constructor(template) {
      if (typeof template == 'string') {
        console.warn('[DEPRECATED] Passing a template name to the HTX.Component constructor is ' +
          'deprecated: pass a direct template function reference instead')
      }

      this.template = HTX.Renderer.templateResolver(template, this, true)
    }

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

  HTX.Component = Component
})(globalThis.HTX ||= {});

const HTXComponent = new Proxy(globalThis.HTX.Component, {
  get(target, property, receiver) {
    if (property == 'prototype') {
      console.warn('[DEPRECATED] Top-level HTXComponent variable is deprecated: use ' +
        'globalThis.HTX.Component instead')
    }

    return target[property]
  }
});
