const ELEMENT   = 1 << 0
const CHILDLESS = 1 << 1
const XMLNS     = 1 << 2
const FLAG_BITS = 3

/**
 * Renderer is used by compiled HTX templates to render themselves. It should never be used directly.
 */
export class Renderer {
  /**
   * Temporary function to handle deprecated way of looking up a template.
   *
   * @param template Name of or direct reference to template function
   * @param context Context (`this` binding) for the template function call.
   * @param isComponent Boolean indicating if the caller is from HTX.Component.
   * */
  static templateResolver(template, context, isComponent = false) {
    let templateFcn, refStr

    if (typeof template == 'string') {
      refStr = `${globalThis.HTX.templates ? 'globalThis.HTX.templates' : 'globalThis'}['${template}']`

      isComponent && console.warn('DEPRECATED: Passing a template string to the HTX.Component ' +
        `constructor is deprecated. Pass a direct template function reference instead: ${refStr}`)

      templateFcn = (globalThis.HTX.templates || globalThis)[template]
    } else {
      templateFcn = template
      refStr = templateFcn ? (templateFcn.name || '<anonymousFunction>') : 'undefined'
    }

    !isComponent && console.warn('DEPRECATED: new HTX(...) is deprecated. Instantiate template directly ' +
      `instead: new ${refStr}(context)`)

    if (!templateFcn) throw `Template not found: ${template}`
    return new templateFcn(context)
  }

  /**
   * Creates a new HTX instance.
   *
   * @constructor
   * @param template Name of or direct reference to a template function.
   * @param context Context (`this` binding) for the template function call.
   */
  constructor(template, context) {
    this._staticKeys = new WeakMap
    this._dynamicKeys = new WeakMap
    this._dynamicIndex = {}
  }

  /**
   * Appends or updates a node.
   *
   * @param object Tag name (e.g. 'div'), Node object, object with a `render` function which returns a
   *   Node object, or any other object which will be cast to a string and inserted as text.
   * @param args First N (optional) are node attributes in the form key1, value1, key2, value2, ....
   *   Second-to-last (optional) is the node's dynamic key (user-provided key for loop-based content to
   *   optimize update performance). Last (required) is the node's static key (compiler-generated index
   *   for this specific node within the tree of all potential DOM nodes) bitwise left shifted and ORed
   *   with any flags.
   */
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

    // Remove current node and advance to its next sibling until static key matches or is past that of the
    // node being appended/updated.
    while (currentNode && this._staticKeys.get(currentNode) < staticKey) {
      let tmpNode = currentNode
      currentNode = currentNode.nextSibling
      tmpNode.remove()
    }

    let staticKeyMatch = this._staticKeys.get(currentNode) == staticKey
    let exists = staticKeyMatch && this._dynamicKeys.get(currentNode) == dynamicKey

    // If there's a dynamic key but the current node isn't a match, find any potential existing node and
    // move it to the current position.
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

    // Add/update the node's attributes.
    for (let i = 0; i < args.length - 2; i += 2) {
      let k = args[i]
      let v = args[i + 1]

      if (k == 'class' && v instanceof Array) {
        v = v.filter(Boolean).join(' ') || null
      }

      // Needed in (non-latest versions of) Safari to refresh the state of the parent <select> tag
      // (setAttribute alone doesn't trigger it).
      if (node.tagName == 'OPTION' && k == 'selected') {
        node[k] = v
      }

      v === false || v === null || v === undefined ? node.removeAttribute(k) :
        node.setAttribute(k, v === true ? '' : v)
    }

    if (!parentNode) {
      // Root node, so nothing to do.
    } else if (!currentNode || currentNode == parentNode) {
      parentNode.append(node)
    } else if (node != currentNode) {
      parentNode.insertBefore(node, currentNode)
    }

    this._currentNode = node

    if ((flags & ELEMENT) && !(flags & CHILDLESS)) this._parentNode = node
  }

  /**
   * Moves parent node pointer up N nodes on the ancestor tree and handles removal of any child nodes that
   * should no longer exist. The current node is updated to be the last parent node traversed.
   *
   * @param count Number of nodes to close (default: 1).
   */
  close(count = 1) {
    while (count-- > 0) {
      // If the current node is the one being closed, we did not walk into it to render any children, so
      // ensure any children that may exist from the previous render are removed.
      if (this._currentNode == this._parentNode) {
        while (this._currentNode.firstChild) {
          this._currentNode.firstChild.remove()
        }
      // Otherwise the current node is the last that should exist within its parent, so ensure any nodes
      // after it that may exist from the previous render are removed.
      } else {
        while (this._currentNode.nextSibling) {
          this._currentNode.nextSibling.remove()
        }
      }

      this._currentNode = this._parentNode
      this._parentNode = this._parentNode.parentNode
    }

    if (this._staticKeys.get(this._currentNode) == 1) {
      this.rootNode = this._currentNode
      this._dynamicIndex = this._dynamicIndexTmp
      delete this._dynamicIndexTmp
    }
  }
}
