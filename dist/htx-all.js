/**
 * HTX
 * Copyright 2019-2022 Nate Pickens
 *
 * @license MIT
 * @version 0.0.8
 */
let HTX = function() {
  const ELEMENT   = 1 << 0
  const CHILDLESS = 1 << 1
  const XMLNS     = 1 << 2
  const FLAG_BITS = 3

  let instances = new WeakMap

  return class {
    static render(object, context) {
      console.warn('HTX.render is deprecated. Please use new HTX(...).render() instead.')

      let htx

      if (object instanceof Node) {
        htx = instances.get(object)
        if (!htx) throw `HTX instance not found for Node: ${object}`
        if (context) htx._context = context
      } else {
        htx = new HTX(object, context)
      }

      return htx.render()
    }

    constructor(template, context) {
      this._template = (HTX.templates || window)[template] || template
      this._context = context
      this._staticKeys = new WeakMap
      this._dynamicKeys = new WeakMap
      this._dynamicIndex = {}

      if (!this._template) throw `Template not found: ${template}`
    }

    render() {
      this._template.call(this._context, this)

      return htx._currentNode
    }

    node(object, ...args) {
      let node
      let currentNode = this._currentNode
      let parentNode = this._parentNode

      let l = args.length
      let flags = args[l - 1]
      let staticKey = args[l - 1] >> FLAG_BITS
      let dynamicKey = l % 2 == 0 && args[l - 2]
      let fullKey = `${staticKey}:${dynamicKey}`

      if (staticKey == 1) {
        this._dynamicIndexTmp = {}
      } else if (currentNode == parentNode) {
        currentNode = parentNode.firstChild
      } else {
        currentNode = currentNode.nextSibling
      }

      while (currentNode && this._staticKeys.get(currentNode) < staticKey) {
        let tmpNode = currentNode
        currentNode = currentNode.nextSibling
        tmpNode.remove()
      }

      let staticKeyMatch = this._staticKeys.get(currentNode) == staticKey
      let exists = staticKeyMatch && this._dynamicKeys.get(currentNode) == dynamicKey

      if (dynamicKey && staticKeyMatch && !exists) {
        let existingNode = this._dynamicIndex[fullKey]

        if (existingNode) {
          currentNode.parentNode.insertBefore(existingNode, currentNode)
          exists = !!(currentNode = existingNode)
        }
      }

      if (flags & ELEMENT) {
        if (exists) {
          node = currentNode
        } else if (flags & XMLNS) {
          node = document.createElementNS(args[args.indexOf('xmlns') + 1 || -1] || parentNode.namespaceURI,
            object)
        } else {
          node = document.createElement(object)
        }
      } else {
        if (object && object.render instanceof Function) object = object.render()
        if (object === null || object === undefined) object = ''

        if (object instanceof Node) {
          node = object
        } else if (exists && currentNode.nodeType == 3) {
          node = currentNode

          let text = object.toString()
          if (node.nodeValue != text) node.nodeValue = text
        } else {
          node = document.createTextNode(object)
        }
      }

      if (node != currentNode) {
        this._staticKeys.set(node, staticKey)
        this._dynamicKeys.set(node, dynamicKey)
      }

      if (dynamicKey) this._dynamicIndexTmp[fullKey] = node

      for (let i = 0; i < args.length - 2; i += 2) {
        let k = args[i]
        let v = args[i + 1]
        let falsey = v === false || v === null || v === undefined

        if (node.tagName == 'OPTION' && k == 'selected') {
          node[k] = v
        }

        falsey ? node.removeAttribute(k) : node.setAttribute(k, v === true ? '' : v)
      }

      if (!parentNode) {
        instances.set(node, this)
      } else if (!currentNode || currentNode == parentNode) {
        parentNode.append(node)
      } else if (node != currentNode) {
        parentNode.insertBefore(node, currentNode)
      }

      this._currentNode = node

      if ((flags & ELEMENT) && !(flags & CHILDLESS)) this._parentNode = node
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
      }

      if (this._staticKeys.get(this._currentNode) == 1) {
        this._dynamicIndex = this._dynamicIndexTmp
        delete this._dynamicIndexTmp
      }
    }
  }
}()

/**
 * HTXComponent
 * Copyright 2019-2022 Nate Pickens
 *
 * @license MIT
 * @version 0.0.8
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
      this.node = htx.render()

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
