/**********************************************************************************************************/
/* HTX                                                                                                    */
/**********************************************************************************************************/

const HTX_CHILDLESS = 1
const HTX_TEXT = 2

class HTX {
  /**
   * Creates a new HTX instance. Each new instance increments a universal ID used to generate unique static
   * and dynamic key property names, ensuring the properties on any child nodes that are also managed by HTX
   * do not get trampled.
   */
  constructor() {
    HTX.id = HTX.id || 0
    HTX.id++

    this.stack = []
    this.staticKeyProp = `__htx${HTX.id}SK__`
    this.dynamicKeyProp = `__htx${HTX.id}DK__`
  }

  /**
   * Appends or updates a node.
   *
   * @param object A tag name (e.g. 'div'), plain text, Node object, or an object with a `render` function
   *   that returns a Node object.
   * @param staticKey Index for this specific node within the tree of all potential DOM nodes.
   * @param dynamicKey Optional key for loop-based content to improve performance of updates.
   * @param flags Bitwise flags indicating properties of this node:
   *   HTX_CHILDLESS The node does not have any child nodes.
   *   HTX_TEXT The first parameter is text to be rendered (as opposed to the name of a tag).
   * @param ...attrs Optional node attributes in the form key1, value1, key2, value2, ....
   */
  node(object, staticKey, dynamicKey, flags, ...attrs) {
    let node
    let currentNode = this.currentNode
    let parentNode = this.stack[this.stack.length - 1]

    let staticKeyProp = this.staticKeyProp
    let dynamicKeyProp = this.dynamicKeyProp

    // Walk, unless we're working on the root node.
    if (staticKey == 1) {
      currentNode = this.rootNode
    } else {
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
    while (currentNode && currentNode[staticKeyProp] < staticKey) {
      let tmpNode = currentNode
      currentNode = currentNode.nextSibling
      tmpNode.remove()
    }

    // If next sibling is an exact match, an item was likely removed from loop-generated content, so remove
    // the current node and move to its next sibling.
    if (
      currentNode &&
      currentNode[staticKeyProp] == staticKey &&
      currentNode[dynamicKeyProp] != dynamicKey &&
      currentNode.nextSibling &&
      currentNode.nextSibling[staticKeyProp] == staticKey &&
      currentNode.nextSibling[dynamicKeyProp] == dynamicKey
    ) {
      currentNode = currentNode.nextSibling
      currentNode.previousSibling.remove()
    }

    // If current node is an exact match, use it.
    if (
      currentNode &&
      currentNode[staticKeyProp] == staticKey &&
      currentNode[dynamicKeyProp] == dynamicKey
    ) {
      node = currentNode

      if (node instanceof Text && node.nodeValue !== object) {
        node.nodeValue = object
      }
    } else {
      if (object instanceof Node) {
        node = object
      } else if (object && object.render instanceof Function) {
        node = object.render()
      } else if (!object || flags & HTX_TEXT) {
        node = document.createTextNode((object === null || object === undefined) ? '' : object)
      } else if (object == 'svg' || this.svg) {
        node = document.createElementNS('http://www.w3.org/2000/svg', object)
        this.svg = true
      } else {
        node = document.createElement(object)
      }

      node[staticKeyProp] = staticKey
      node[dynamicKeyProp] = dynamicKey
    }

    // Add/update the node's attributes.
    for (let k = 0, v = 1; v < attrs.length; k += 2, v += 2) {
      let isInputValue = node.tagName == 'INPUT' && attrs[k] == 'value'
      let currentValue = isInputValue ? node.value : node.attributes[attrs[k]]
      let value = attrs[v]

      if (currentValue !== value) {
        if (isInputValue) {
          node.value = value
        } else {
          value === false || value === null || value === undefined ? node.removeAttribute(attrs[k]) :
          value === true ? node.setAttribute(attrs[k], '') :
          node.setAttribute(attrs[k], value)
        }
      }
    }

    if (!parentNode) {
      this.rootNode = node
      node.__htx__ = this
    } else if (!currentNode || currentNode == parentNode) {
      parentNode.append(node)
    } else if (node != currentNode) {
      parentNode.insertBefore(node, currentNode)
    }

    this.currentNode = node

    if (!(flags & HTX_CHILDLESS)) this.stack.push(node)
  }

  /**
   * Pops the top N nodes off the stack and handles removal of any child nodes that should no longer exist.
   * `this.currentNode` is updated to be the last node popped off the stack.
   *
   * @param count Number of nodes on the stack to close (default: 1).
   */
  close(count = 1) {
    while (count-- > 0) {
      let parentNode = this.stack.pop()

      // If the current node is the one being closed, we did not walk into it to render any children, so
      // ensure any children that may exist from the previous render are removed.
      if (this.currentNode == parentNode) {
        while (this.currentNode.firstChild) {
          this.currentNode.firstChild.remove()
        }
      // Otherwise the current node is the last that should exist within its parent, so ensure any nodes
      // after it that may exist from the previous render are removed.
      } else {
        while (this.currentNode && this.currentNode.nextSibling) {
          this.currentNode.nextSibling.remove()
        }
      }

      this.currentNode = parentNode

      if (this.currentNode.tagName == 'svg') this.svg = false
    }
  }
}
