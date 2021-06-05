/**
 * HTX
 * Copyright 2019-2021 Nate Pickens
 *
 * @license MIT
 * @version 0.0.5
 */
let HTX = function() {
  const CHILDLESS = 0b01
  const TEXT_NODE = 0b10
  const FLAG_MASK = 0b11
  const FLAG_BITS = 2

  const UNKNOWN_PLACEHOLDER = '[HTX:unknown]'

  let instances = new WeakMap

  return class {
    static render(object, context) {
      let htx = instances.get(object) || new HTX((HTX.templates || window)[object] || object)
      if (!htx) throw `Template not found: ${object}`

      if (context) htx._context = context
      htx._template.call(htx._context, htx)

      return htx._currentNode
    }

    constructor(template) {
      this._template = template
      this._staticKeys = new WeakMap
      this._dynamicKeys = new WeakMap
    }

    node(object, ...args) {
      let node
      let currentNode = this._currentNode
      let parentNode = this._parentNode

      let l = args.length
      let flags = args[l - 1] & FLAG_MASK
      let staticKey = args[l - 1] >> FLAG_BITS
      let dynamicKey = l % 2 == 0 ? args[l - 2] : undefined

      if (staticKey != 1) {
        if (parentNode && currentNode == parentNode) {
          currentNode = parentNode.firstChild
        } else {
          currentNode = currentNode.nextSibling
        }
      }

      while (currentNode && this._staticKeys.get(currentNode) < staticKey) {
        let tmpNode = currentNode
        currentNode = currentNode.nextSibling
        tmpNode.remove()
      }

      if (
        this._staticKeys.get(currentNode) == staticKey &&
        this._dynamicKeys.get(currentNode) != dynamicKey &&
        this._staticKeys.get(currentNode.nextSibling) == staticKey &&
        this._dynamicKeys.get(currentNode.nextSibling) == dynamicKey
      ) {
        currentNode = currentNode.nextSibling
        currentNode.previousSibling.remove()
      }

      if (
        this._staticKeys.get(currentNode) == staticKey &&
        this._dynamicKeys.get(currentNode) == dynamicKey && !(
          currentNode instanceof Comment &&
          currentNode.nodeValue == UNKNOWN_PLACEHOLDER &&
          object !== null &&
          object !== undefined
        )
      ) {
        node = currentNode

        if (node instanceof Text && node.nodeValue !== object) {
          node.nodeValue = object
        }
      } else {
        if (object === null || object === undefined) {
          node = document.createComment(UNKNOWN_PLACEHOLDER)
        } else if (object instanceof Node) {
          node = object
        } else if (object && object.render instanceof Function) {
          node = object.render()
        } else if (flags & TEXT_NODE) {
          node = document.createTextNode(object)
        } else if (object == 'svg' || this.svg) {
          node = document.createElementNS('http://www.w3.org/2000/svg', object)
          this.svg = true
        } else {
          node = document.createElement(object)
        }

        this._staticKeys.delete(currentNode)
        this._dynamicKeys.delete(currentNode)

        this._staticKeys.set(node, staticKey)
        this._dynamicKeys.set(node, dynamicKey)
      }

      for (let k = 0, v = 1; v < args.length - 1; k += 2, v += 2) {
        if (
          (node.tagName == 'INPUT' || node.tagName == 'SELECT') &&
          (args[k] == 'value' || args[k] == 'checked')
        ) {
          node[args[k]] = args[v]
        } else if (args[v] === false || args[v] === null || args[v] === undefined) {
          node.removeAttribute(args[k])
        } else {
          node.setAttribute(args[k], args[v] === true ? '' : args[v])
        }
      }

      if (!parentNode) {
        instances.set(node, this)
      } else if (!currentNode || currentNode == parentNode) {
        parentNode.append(node)
      } else if (node != currentNode) {
        parentNode.insertBefore(node, currentNode)
      }

      this._currentNode = node

      if (!(flags & (CHILDLESS | TEXT_NODE))) this._parentNode = node
    }

    close(count = 1) {
      while (count-- > 0) {
        let currentNode = this._currentNode
        let parentNode = this._parentNode

        this._parentNode = parentNode.parentNode

        if (currentNode == parentNode) {
          while (currentNode.firstChild) {
            currentNode.firstChild.remove()
          }
        } else {
          while (currentNode && currentNode.nextSibling) {
            currentNode.nextSibling.remove()
          }
        }

        this._currentNode = parentNode

        if (this._currentNode.tagName == 'svg') this.svg = false
      }
    }
  }
}()

/**
 * HTXComponent
 * Copyright 2019-2021 Nate Pickens
 *
 * @license MIT
 * @version 0.0.5
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
