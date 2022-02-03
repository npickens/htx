/**
 * HTX
 * Copyright 2019-2022 Nate Pickens
 *
 * @license MIT
 */
let HTX = function() {
  const CHILDLESS  = 0b001
  const TEXT_NODE  = 0b010
  const XMLNS_NODE = 0b100
  const FLAG_MASK  = 0b111
  const FLAG_BITS  = 3

  const UNKNOWN_PLACEHOLDER = '[HTX:unknown]'

  let instances = new WeakMap

  return class {
    /**
     * Calls a template function to either create a new Node or update an existing one.
     *
     * @param object The name of a template function, a reference to a template function, or a Node object
     *   previously returned by this function that needs updating.
     * @param context The context (`this` binding) for the template function call (optional).
     */
    static render(object, context) {
      let htx = instances.get(object) || new HTX((HTX.templates || window)[object] || object)
      if (!htx) throw `Template not found: ${object}`

      if (context) htx._context = context
      htx._template.call(htx._context, htx)

      return htx._currentNode
    }

    /**
     * Creates a new HTX instance.
     *
     * @constructor
     */
    constructor(template) {
      this._template = template
      this._xmlnsStack = []
      this._staticKeys = new WeakMap
      this._dynamicKeys = new WeakMap
    }

    /**
     * Appends or updates a node.
     *
     * @param object A tag name (e.g. 'div'), plain text, Node object, or an object with a `render` function
     *   that returns a Node object.
     * @param args First N (optional) are node attributes in the form key1, value1, key2, value2, ....
     *   Second-to-last (optional) is the node's dynamic key (user-provided key for loop-based content to
     *   optimize update performance). Last (required) is the node's static key (compiler-generated index
     *   for this specific node within the tree of all potential DOM nodes) bitwise left shifted and ORed
     *   with any flags: CHILDLESS = this node does not have any children; TEXT_NODE = the first argument is
     *   text to be rendered (as opposed to the name of a tag).
     */
    node(object, ...args) {
      let node
      let currentNode = this._currentNode
      let parentNode = this._parentNode

      let l = args.length
      let flags = args[l - 1] & FLAG_MASK
      let staticKey = args[l - 1] >> FLAG_BITS
      let dynamicKey = l % 2 == 0 ? args[l - 2] : undefined

      // Walk, unless we're working on the root node.
      if (staticKey != 1) {
        // If the current node is also the current parent node, descend into it.
        if (parentNode && currentNode == parentNode) {
          currentNode = parentNode.firstChild
        // Otherwise go to the next sibling of the current node.
        } else {
          currentNode = currentNode.nextSibling
        }
      }

      // Remove current node and advance to its next sibling until static key matches or is past that of the
      // node being appended/updated.
      while (currentNode && this._staticKeys.get(currentNode) < staticKey) {
        let tmpNode = currentNode
        currentNode = currentNode.nextSibling
        tmpNode.remove()
      }

      // If next sibling is an exact match, an item was likely removed from loop-generated content, so
      // remove the current node and move to its next sibling.
      if (
        this._staticKeys.get(currentNode) == staticKey &&
        this._dynamicKeys.get(currentNode) != dynamicKey &&
        this._staticKeys.get(currentNode.nextSibling) == staticKey &&
        this._dynamicKeys.get(currentNode.nextSibling) == dynamicKey
      ) {
        currentNode = currentNode.nextSibling
        currentNode.previousSibling.remove()
      }

      // If current node is an exact match, use it.
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
        } else if (flags & XMLNS_NODE || this._xmlnsStack.length > 0) {
          let xmlns = (flags & XMLNS_NODE) ? args[args.indexOf('xmlns') + 1]
                                           : this._xmlnsStack[0].namespaceURI

          node = document.createElementNS(xmlns, object)

          if (flags & XMLNS_NODE) this._xmlnsStack.unshift(node)
        } else {
          node = document.createElement(object)
        }

        this._staticKeys.delete(currentNode)
        this._dynamicKeys.delete(currentNode)

        this._staticKeys.set(node, staticKey)
        this._dynamicKeys.set(node, dynamicKey)
      }

      // Add/update the node's attributes.
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

    /**
     * Moves parent node pointer up N nodes on the ancestor tree and handles removal of any child nodes that
     * should no longer exist. The current node is updated to be the last parent node traversed.
     *
     * @param count Number of nodes to close (default: 1).
     */
    close(count = 1) {
      while (count-- > 0) {
        let currentNode = this._currentNode
        let parentNode = this._parentNode

        this._parentNode = parentNode.parentNode

        // If the current node is the one being closed, we did not walk into it to render any children, so
        // ensure any children that may exist from the previous render are removed.
        if (currentNode == parentNode) {
          while (currentNode.firstChild) {
            currentNode.firstChild.remove()
          }
        // Otherwise the current node is the last that should exist within its parent, so ensure any nodes
        // after it that may exist from the previous render are removed.
        } else {
          while (currentNode && currentNode.nextSibling) {
            currentNode.nextSibling.remove()
          }
        }

        if (this._xmlnsStack.length > 0 && parentNode == this._xmlnsStack[0]) {
          this._xmlnsStack.shift()
        }

        this._currentNode = parentNode
      }
    }
  }
}()
