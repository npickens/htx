/**
 * HTX.Renderer
 * Copyright 2019-2025 Nate Pickens
 *
 * @license MIT
 * @version 1.0.1
 */
(HTX => {
  const ELEMENT   = 1 << 0
  const CHILDLESS = 1 << 1
  const XMLNS     = 1 << 2
  const FLAG_BITS = 3

  class Renderer {
    constructor() {
      this._staticKeys = new WeakMap
      this._dynamicKeys = new WeakMap
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
        this._previousDynamicIndex = new WeakRef(this._dynamicIndex || {})
        this._dynamicIndex = {}
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
        let existingNode = this._previousDynamicIndex[fullKey]

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

      if (dynamicKey) this._dynamicIndex[fullKey] = node

      for (let i = 0; i < args.length - 2; i += 2) {
        let k = args[i]
        let v = args[i + 1]

        if (k == 'class' && v instanceof Array) {
          v = v.filter(Boolean).join(' ') || null
        }

        let empty = v === null || v === undefined

        if (
          (node.tagName == 'INPUT' && (k == 'value' || k == 'checked')) ||
          (node.tagName == 'OPTION' && k == 'selected')
        ) {
          node[k] = empty ? null : v
        } else {
          empty || v === false ? node.removeAttribute(k) : node.setAttribute(k, v === true ? '' : v)
        }
      }

      if (!parentNode) {
        this.rootNode = node
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
        if (this._currentNode == this._parentNode) {
          while (this._currentNode.firstChild) {
            this._currentNode.firstChild.remove()
          }
        } else {
          while (this._currentNode.nextSibling) {
            this._currentNode.nextSibling.remove()
          }
        }

        this._currentNode = this._parentNode
        this._parentNode = this._parentNode.parentNode
      }
    }
  }

  HTX.Renderer = Renderer
})(globalThis.HTX ||= {});

