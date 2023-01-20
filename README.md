# HTX

HTX is a full-featured HTML template system that is simple, lightweight, and highly performant.

1. **Template Syntax** — A simple combination of HTML and JavaScript. No sugar added.
2. **Compilation** — Templates are precompiled to JavaScript. A DOM both generated and manipulated by
   JavaScript is a consistent DOM.
3. **JavaScript Library** — Small bit of code (1KB minified and gzipped) called by compiled template
   functions to very efficiently render and update the DOM in place. No virtual DOM necessary.

## Overview

All uncompiled HTX templates are valid HTML documents. JavaScript syntax is leveraged in attribute values
and tag content to issue control statements and render dynamic content. Here's an example (see the [Template
Syntax](#template-syntax) section for the full spec):

```html
<div class='crew'>
  <h1>${this.title}</h1>

  <ul class='members'>
    for (let member of this.member) {
      <li class='member ${member.role}'>
        ${member.name}
      </li>
    }
  </ul>
</div>
```

An HTX template gets compiled to a JavaScript function consisting of calls to the (very tiny) HTX JavaScript
library. The full compiled version of the above template is shown in the [Compiler](#compiler) section, but
in summary it takes the following form:

```javascript
globalThis['/components/crew.htx'] = function(htx) {
  // ...
}
```

The HTX library leverages this function to both generate a brand new DOM fragment and update an existing
one:

```javascript
let crew = {
  title: 'Serenity Crew',
  members: [
    {role: 'captain', name: 'Mal'},
    {role: 'first-mate', name: 'Zoe'},
    {role: 'mercenary', name: 'Jayne'},
  ],
}

// The constructor takes the name of or direct reference to a template function and a context
// (`this` binding) to use whenever the template function is called.
let htx = new HTX('/components/crew.htx', crew)

// The `render` function returns a standard Node object.
document.body.append(htx.render())

// Subsequent calls re-render the existing Node, in this case refreshing it to reflect the
// current state of the `crew` object.
crew.members.push({role: 'pilot', name: 'Wash'})
htx.render()
```

The result:

```html
<div class='crew'>
  <h1>Serenity Crew</h1>

  <ul class='members'>
    <li class='member captain'>Mal</li>
    <li class='member first-mate'>Zoe</li>
    <li class='member mercenary'>Jayne</li>
    <li class='member pilot'>Wash</li>
  </ul>
</div>
```

## HTX Versus JSX

For those familiar with JSX, think of HTX as the reverse: instead of embedding HTML syntax within
JavaScript, JavaScript is embedded within HTML. Syntax aside, HTX has two key advantages over JSX:

1. **HTX DOM updates are both faster and more memory efficient than those of JSX.** HTX leverages the DOM
   directly to track changes and perform updates. There is no virtual DOM.  See the [JavaScript
   Library](#javascript-library) section for how it works and the [Performance](#performance) section for
   benchmark results.
2. **HTX permits any JavaScript code to be used as control statements.** Whereas JSX requires ternary
   operators for conditionals and `map` calls for loops, HTX permits plain old `if` statements and `for`
   loops (though the former may be used if so desired).

## Template Syntax

As stated above, HTX templates are HTML documents with JavaScript syntax inserted for control flow and to
render dynamic content.

### Control Flow

A tag's content (text node) is interpreted as a control statement by the compiler and inserted directly into
the generated JavaScript function if it contains any of the following:

* A variable assignment or increment/decrement (examples: `greeting = 'hello'` or `i += 1`)
* A function call (example: `this.greet('hello')`)
* An object reference using square brackets (example: `this.members[0]`)
* An opening or closing curly brace (`{` or `}`)

```html
<!-- Template -->
<div id='container'>
  for (let i = 0; i < 3; i++) {
    <div>Hello</div>
  }
</div>

<!-- Result -->
<div id='container'>
  <div>Hello</div>
  <div>Hello</div>
  <div>Hello</div>
</div>
```

**IMPORTANT NOTE 1:** Curly braces should always be used, even for single-line loops, `if` statements, and
arrow function expressions. Control statements are directly inserted into the compiled JavaScript code, but
live alongside compiler-generated statements. The latter may not do what they are supposed to if curly
braces are omitted. See the [Compiler](#compiler) section for more detail.

**IMPORTANT NOTE 2:** Though JavaScript syntax allows whitespace between an identifier and a parenthesis or
square bracket, HTX will only recognize function calls and object references as control statements if there
is no whitespace. **DO** `this.greet('hello')` and `this.members[0]`. **DO NOT** `this.greet ('hello')` and
`this.members [0]`.

### Output

Rendering dynamic content happens by way of JavaScript's string interpolation syntax, `${...}`. A tag's
content is interpreted by the compiler as output to render if any of the following are true:

1. None of the conditions for being a control statement (see above) are met.
   ```html
   <!-- Template -->
   <div>Hello, World!</div>

   <!-- Result -->
   <div>Hello, World!</div>
   ```

2. None of the conditions for being a control statement are met except interpolations (`${...}`).
   ```html
   <!-- Template -->
   <div>Hello, ${this.name}!</div>

   <!-- Result when this.name is 'Mal' -->
   <div>Hello, Mal!</div>
   ```

3. The entire text (other than leading and trailing whitespace) is quoted with backticks and/or encapsulated
   in `${...}`.
   ```html
   <!-- Template -->
   <div>`The Serenity crew is led by ${this.captain} (and ${this.firstMate}).`</div>
   <div>${this.captain + ' is captain; ' + this.firstMate + ' is his first mate.'}</div>

   <!-- Result when this.captain is 'Mal' and this.firstMate is 'Zoe' -->
   <div>The Serenity crew is led by Mal (and Zoe).</div>
   <div>Mal is captain; Zoe is his first mate.</div>
   ```

#### Special Objects

If a tag's content is encapsulated entirely in `${...}`, the resulting value is handled as follows:

1. A value of **`null` or `undefined`** is treated as empty text.

    ```html
    <!-- Template -->
    <div>${this.cook}</div>

    <!-- Result when this.cook is null or undefined -->
    <div></div>
    ```

2. A **Node object** is inserted directly into the DOM.

   ```html
   <!-- Template -->
   <div>${this.mechanicNode}</div>

   <!-- Result when this.mechanicNode is a <span> Node object -->
   <div><span class='crew-member'>Kaylee Frye, Mechanic</span></div>
   ```

3. An **object with a `render` function** is replaced with the returned value from calling the `render`
   function. This value is then handled as it would have been if it were the original object. This is
   particularly useful when using the optional [HTX Component](#htx-component) library.

   ```html
   <!-- Template -->
   <div>${this.doctor}</div>

   <!-- Result when this.doctor.render() returns a <span> Node object -->
   <div><span class='crew-member'>Simon Tam, Doctor</span></div>
   ```

4. **Any other object** is cast to a string and inserted as text.

    ```html
    <!-- Template -->
    <div>${this.passengers}</div>

    <!-- Result when this.passengers is an array of strings -->
    <div>Shepherd Book,River Tam</div>
    ```

**IMPORTANT NOTE:** Special objects are only handled as such when the entire value of a tag's content is an
interpolation. Any object that is mixed with string content will be cast to a string upon insertion.

```html
<!-- Template -->
<div>${this.pilot}, nickname "Wash"</div>

<!-- Result when this.pilot is an object with a render function -->
<div>[object Object], nickname "Wash"</div>
```

#### Tagless Output

Content can be rendered without an enclosing tag by wrapping it in HTX's special tag,
`<htx-content>...</htx-content>`. This is useful within a control loop or conditional when output is desired
without the creation of an additional HTML element. (Note: this tag may not contain any child tags and the
only attribute allowed is `htx-key`.)

```html
<!-- Template -->
<textarea class='names'>
  for (let member of this.members) {
    <htx-content>${member.name}...</htx-content>
  }
</textarea>

<!-- Result -->
<textarea class='names'>
  Mal...Zoe...Jayne...
</textarea>
```

#### Keys

For optimal performance when rendering content via a loop, a unique key can be provided for each item by way
of an `htx-key` attribute (those familiar with JSX will recognize this functionality). This attribute is not
included as an actual attribute on the resulting DOM node, but is leveraged by the [JavaScript
Library](#javascript-library) to optimize the performance of DOM updates.

```html
<ul class='members'>
  for (let member of this.members) {
    <li class='member ${member.role}' htx-key='${member.id}'>
      ${member.name}
    </li>
  }
</ul>
```

### Attributes

Tag attribute values can also contain dynamic content. Since control statements do not make sense within
this context, attribute values are simpler in that they always behave like JavaScript template strings.
Example:

```html
<!-- Template -->
<li class='member ${member.role}'>...</li>

<!-- Result when member.role is 'captain' -->
<li class='member captain'>...</li>
```

A special case is made for boolean(ish) values: if the attribute value is strictly JavaScript (no static
parts to it) and evaluates to `true`, `false`, `null`, or `undefined`, the attribute is treated as a boolean
attribute. Example:

```html
<!-- Template -->
<li class='member' selected='${member.selected}'>...</div>

<!-- Result when member.selected === true -->
<li class='member' selected>...</div>

<!-- Result when member.selected === false, null, or undefined -->
<li class='member'>...</div>
```

One other special case is made for `class` attributes: if the attribute value is strictly JavaScript (no
static parts to it) and is an array, it is automatically converted to a space-separated string with only
truthy values included. Example:

```html
<!-- Template -->
<li class='${["member", member.selected && "selected"]'>...</div>

<!-- Result when member.selected is truthy -->
<li class='member selected'>...</div>

<!-- Result when member.selected is not truthy -->
<li class='member'>...</div>
```

## Compiler

The HTX compiler is written in Ruby. That being said, since HTX templates are valid HTML documents, porting
to other languages should be fairly straightforward considering an HTML parsing library can be leveraged to
do the bulk of the heavy lifting (as is the case with the Ruby compiler, which leverages Nokogiri).

Calling the compiler is simple:

```ruby
path = '/components/crew.htx'
content = File.read("/assets#{path}")

HTX.compile(path, content)

# Or to attach to a custom object instead of `globalThis`:
HTX.compile(path, content, assign_to: 'myTemplates')
```

Result:

```javascript
globalThis['/components/crew.htx'] = function(htx) {
  htx.node('div', 'class', `crew`, 8)
    htx.node('h1', 16); htx.node(this.title, 26); htx.close()

    htx.node('ul', 'class', `members`, 32)
      for (let member of this.members) {
        htx.node('li', 'class', `member ${member.role}`, 40)
          htx.node(member.name, 50)
        htx.close()
      }
  htx.close(2)
}

// If `assign_to` is specified:
myTemplates['/components/crew.htx'] = function(htx) {
  // ...
}
```

(Note: if the `assign_to` compile option is specified, set `HTX.templates = myTemplates` before rendering
any templates so HTX knows where to look for compiled template functions.)

Every compiled template function is just a series of calls to the HTX JavaScript library, with any control
statements from the template inserted appropriately. See the [JavaScript Library](#javascript-library)
section for details on how it works.

As stated previously, it is important to always use curly braces for control statements, even if they seem
optional when writing the template. Even though the `for` loop in the uncompiled template only contains one
child/tag, note that it turns into three lines of code in the compiled function.

## JavaScript Library

The magic behind HTX's efficient DOM management lies in the assignment of an incrementing integer key to
each potential node that can be rendered. This key is internally referred to as the 'static' key (while the
optional user-provided key of loop-generated content is the 'dynamic' key). HTX updates the DOM by walking
the DOM tree and examining each node's static key to determine which nodes should be added or removed.

This is best shown with an example. Consider the following template:

```html
<div> <!-- key = 1 -->
  if (this.shuttleCount < 2) {
    <span class='wait'>Waiting for Inara...</span> <!-- key = 2 -->
  } else {
    <span class='go'>Good to go!</span> <!-- key = 3 -->
  }
</div>
```

The comment next to each node shows the key assigned to it by the compiler (passed to the `htx.node` call
for that particular node), which is associated with the resulting DOM node object via a WeakMap. Suppose
`this.shuttleCount` is 1 on the first rendering of this template:

```html
<div> <!-- key = 1 -->
  <span class='wait'>Waiting for Inara...</span> <!-- key = 2 -->
</div>
```

Now suppose `this.shuttleCount` has changed to 2 and the template function is called again to refresh the
existing DOM. The HTX JavaScript library will walk the existing DOM tree and make modifications as follows:

1. The first node to be rendered is the parent `<div>` with a key of 1. It already exists, so we walk to the
   next node in the tree: the child `<div>` with key 2.
2. The next node to render has a key of 3, but our current node as we walk the existing DOM has a key of 2.
   Since the current existing node has a key less than the one we want to render, we remove it.
3. The child `<div>` with key 3 is added.

If the reverse were to happen, where the first render produced node 3 and the second produced node 2, the
removal of node 3 would happen upon closing the parent `<div>`: any trailing children not accounted for are
removed.

For text content and attribute values, the existing values in the DOM are updated with the current values as
the tree is walked.

## HTX Component

The HTX Component JavaScript library is a small and optional part of HTX. It provides a simple
`HTXComponent` class designed to be extended by various component classes. The constructor takes the name of
the HTX template function to be used by the component.

```javascript
class Crew extends HTXComponent {
  constructor() {
    super('/components/crew.htx')

    this.members = [
      {role: 'captain', name: 'Mal'},
      {role: 'first-mate', name: 'Zoe'},
      {role: 'mercenary', name: 'Jayne'},
    ]
  }

  // ...
}
```

The class provides a `node` property, which is the root node of the HTX template rendering, and two
functions:

* `mount` — Renders and inserts into the DOM. Should be called once for the initial rendering of the
  component. Accepts two optional arguments: the placement type (`prepend`, `append`, `replace`, `before`,
  or `after`; default is `append`) and an existing DOM node the placement is in relation to (default is
  `document.body`).
* `render` — Renders the component. Should be called on a mounted component whenever it needs to be
  refreshed.

```javascript
// Initial rendering and insertion into the DOM.
let crew = new Crew()
crew.mount('prepend', document.querySelector('#container'))

// The component's render function must be called to refresh the DOM.
crew.members.push({role: 'pilot', name: 'Wash'})
crew.render()
```

An optional `didRender` function can be implemented by the child component class, which will be called
whenever a render occurs. It is passed one argument that is `true` on the initial rendering and `false`
thereafter.

```javascript
class Crew extends HTXComponent {
  // ...

  didRender(initial) {
    if (!initial) return

    let button = this.node.querySelector('.button')
    button.addEventListener('click', event => { /* ... */ })
  }
}
```

## Performance

As stated previously, HTX is both faster and more memory efficient than JSX. Instead of building a virtual
DOM and diff-ing it against the real DOM, HTX walks the actual DOM and updates it on the fly. Doing so is
very performant and has almost no memory overhead.

Performance has been measured with an adaptation of the DBMonster web app. The average of 10 runs each
running on a MacBook Pro, 3.1GHz i7, 16GB memory are as follows:

(**NOTE**: Performance has not been reassessed since a very early version of the HTX library. Stats may
differ now.)

| Metric                | JSX   | HTX   | HTX Improvement |
|-----------------------|-------|-------|-----------------|
| numAnimationFrames    | 179.4 | 225.5 | 26% faster      |
| numFramesSentToScreen | 179.4 | 225.5 | 26% faster      |
| droppedFrameCount     | 349.3 | 279.4 | 20% fewer       |
| meanFrameTime_raf     | 48.85 | 37.16 | 24% shorter     |
| framesPerSec_raf      | 20.47 | 26.92 | 32% more        |
| firstPaint            | 954.3 | 202.7 | 79% faster      |
| loadTime              | 846.6 | 88.9  | 89% faster      |
| domReadyTime          | 147.4 | 46.7  | 68% faster      |
| readyStart            | 3.2   | 1.7   | 47% faster      |
| requestTime           | 2.3   | 1.8   | 22% faster      |
| initDomTreeTime       | 696.9 | 40.4  | 94% faster      |
