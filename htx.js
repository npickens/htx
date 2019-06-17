/**********************************************************************************************************/
/* HTX                                                                                                    */
/**********************************************************************************************************/

const HTX_CHILDLESS = 0b01
const HTX_TEXT_NODE = 0b10
const HTX_FLAG_MASK = 0b11
const HTX_FLAG_BITS = 2

class HTX {
  /**
   * Calls a template function to either create a new Node or update an existing one.
   *
   * @param object The name of a template function, a reference to a template function, or a Node object
   *   previously returned by this function that needs updating.
   * @param context The context (`this` binding) for the template function call (optional).
   */
  static render(object, context) {
    let htx = HTX.instances.get(object) || new HTX(window[object] || object)

    if (context) htx.context = context
    htx.template.call(htx.context, htx)

    return htx.currentNode
  }

  /**
   * Creates a new HTX instance.
   *
   * @constructor
   */
  constructor(template) {
    this.template = template
    this.stack = []
    this.staticKeys = new WeakMap
    this.dynamicKeys = new WeakMap
  }

  /**
   * Appends or updates a node.
   *
   * @param object A tag name (e.g. 'div'), plain text, Node object, or an object with a `render` function
   *   that returns a Node object.
   * @param args First N (optional) are node attributes in the form key1, value1, key2, value2, ....
   *   Second-to-last (optional) is the node's dynamic key (user-provided key for loop-based content to
   *   optimize update performance). Last (required) is the node's static key (compiler-generated index for
   *   this specific node within the tree of all potential DOM nodes) bitwise left shifted and ORed with
   *   any flags: HTX_CHILDLESS = this node does not have any children; HTX_TEXT_NODE = the first argument
   *   is text to be rendered (as opposed to the name of a tag).
   */
  node(object, ...args) {
    let node
    let currentNode = this.currentNode
    let parentNode = this.stack[this.stack.length - 1]

    let l = args.length
    let flags = args[l - 1] & HTX_FLAG_MASK
    let staticKey = args[l - 1] >> HTX_FLAG_BITS
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
    while (currentNode && this.staticKeys.get(currentNode) < staticKey) {
      let tmpNode = currentNode
      currentNode = currentNode.nextSibling
      tmpNode.remove()
    }

    // If next sibling is an exact match, an item was likely removed from loop-generated content, so remove
    // the current node and move to its next sibling.
    if (
      this.staticKeys.get(currentNode) == staticKey &&
      this.dynamicKeys.get(currentNode) != dynamicKey &&
      this.staticKeys.get(currentNode.nextSibling) == staticKey &&
      this.dynamicKeys.get(currentNode.nextSibling) == dynamicKey
    ) {
      currentNode = currentNode.nextSibling
      currentNode.previousSibling.remove()
    }

    // If current node is an exact match, use it.
    if (this.staticKeys.get(currentNode) == staticKey && this.dynamicKeys.get(currentNode) == dynamicKey) {
      node = currentNode

      if (node instanceof Text && node.nodeValue !== object) {
        node.nodeValue = object
      }
    } else {
      if (object instanceof Node) {
        node = object
      } else if (object && object.render instanceof Function) {
        node = object.render()
      } else if (!object || flags & HTX_TEXT_NODE) {
        node = document.createTextNode((object === null || object === undefined) ? '' : object)
      } else if (object == 'svg' || this.svg) {
        node = document.createElementNS('http://www.w3.org/2000/svg', object)
        this.svg = true
      } else {
        node = document.createElement(object)
      }

      this.staticKeys.set(node, staticKey)
      this.dynamicKeys.set(node, dynamicKey)
    }

    // Add/update the node's attributes.
    for (let k = 0, v = 1; v < args.length - 1; k += 2, v += 2) {
      if (
        (node.tagName == 'INPUT' || node.tagName == 'SELECT') &&
        (args[k] == 'value' || args[k] == 'checked')
      ) {
        node.value = args[v]
      } else if (args[v] === false || args[v] === null || args[v] === undefined) {
        node.removeAttribute(args[k])
      } else {
        node.setAttribute(args[k], args[v] === true ? '' : args[v])
      }
    }

    if (!parentNode) {
      HTX.instances.set(node, this)
    } else if (!currentNode || currentNode == parentNode) {
      parentNode.append(node)
    } else if (node != currentNode) {
      parentNode.insertBefore(node, currentNode)
    }

    this.currentNode = node

    if (!(flags & (HTX_CHILDLESS | HTX_TEXT_NODE))) this.stack.push(node)
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

HTX.instances = new WeakMap
