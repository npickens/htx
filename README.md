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
<div class='people'>
  <h1>${this.title}</h1>

  <ul class='people-list'>
    for (let person of this.people) {
      <li class='person ${person.role}'>
        ${person.name}
      </li>
    }
  </ul>
</div>
```

An HTX template gets compiled to a JavaScript function consisting of calls to the (very tiny) HTX JavaScript
library. The full compiled version of the above template is shown in the [Compiler](#compiler) section, but
in summary it takes the following form:

```javascript
window['/components/people.htx'] = function(htx) {
  // ...
}
```

`HTX.render` leverages this function to both generate a brand new DOM fragment and update an existing one:

```javascript
let crew = {
  title: 'Serenity Crew',
  people: [
    {role: 'captain', name: 'Mal'},
    {role: 'first-mate', name: 'Zoe'},
    {role: 'mercenary', name: 'Jayne'},
  ],
}

// HTX.render returns a standard Node object.
let crewNode = HTX.render('/components/people.htx', crew)
document.body.append(crewNode)

HTX.render(crewNode) // Update the DOM when the `crew` object changes.
HTX.render(crewNode, otherCrew) // Update the DOM with an entirely new context.
```

The result:

```html
<div class='people'>
  <h1>Serenity Crew</h1>

  <ul class='people-list'>
    <li class='person captain'>Mal</li>
    <li class='person first-mate'>Zoe</li>
    <li class='person mercenary'>Jayne</li>
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

If a tag's content (text node) contains at least one curly brace, parenthesis, or semicolon, it is
interpreted as a control statement and the compiler directly inserts it into the generated JavaScript
function.

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

**IMPORTANT NOTE:** Curly braces should always be used, even for single-line loops, `if` statements, and
function definitions. Control statements are directly inserted into the compiled JavaScript code, but live
alongside compiler-generated statements. The latter may not do what they are supposed to if curly braces are
omitted. See the [Compiler](#compiler) section for more detail.

### Output

Rendering dynamic content happens by way of JavaScript's string interpolation syntax, `${...}`. A tag's
content is interpreted by the compiler as output to render if any of the following are true:

1. It contains no curly braces, parentheses, or semicolons (i.e. the condition for it being a control
   statement is not met).
   ```html
   <!-- Template -->
   <div>Hello World!</div>

   <!-- Result -->
   <div>Hello World!</div>
   ```

2. It contains no parentheses or semicolons, and its only instances of curly braces are interpolations
   (`${...}`).
   ```html
   <!-- Template -->
   <div>Hello ${this.name}!</div>

   <!-- Result when this.name is 'Mal' -->
   <div>Hello Mal!</div>
   ```

3. It is quoted with backticks and/or encapsulated in `${...}`.
   ```html
   <!-- Template -->
   <div>`The Serenity crew is led by ${this.captain} (and ${this.firstMate}).`</div>
   <div>${this.captain + ' is captain; ' + this.firstMate + ' is his first mate.'}</div>

   <!-- Result when this.captain is 'Mal' and this.firstMate is 'Zoe' -->
   <div>The Serenity crew is led by Mal (and Zoe).</div>
   <div>Mal is captain; Zoe is his first mate.</div>
   ```

#### Node Objects

Output can be either a string (as shown in the examples above) or either of the following:

1. A Node object, in which case the Node will be inserted directly.
   ```html
   <!-- Template -->
   <div>${this.mechanicNode}</div>

   <!-- Result when this.mechanicNode is a <span> Node object -->
   <div><span class='crew-member'>Kaylee Frye, Mechanic</span></div>
   ```

2. An object with a `render` function, in which case the `render` function is called and its return value,
   which must be a Node object, is inserted. This is particularly useful when using the optional [HTX
   Component](#htx-component) library.
   ```html
   <!-- Template -->
   <div>${this.doctor}</div>

   <!-- Result when this.doctor.render() returns a <span> Node object -->
   <div><span class='crew-member'>Simon Tam, Doctor</span></div>
   ```

Note that the above two evaluations are only applied to the entire value of a tag's content—not to
individual parts. Any object that is mixed with string content will be cast to a string upon insertion.

```html
<!-- Template -->
<div>${this.pilot}, nickname "Wash"</div>

<!-- Result when this.pilot is some object with a render function -->
<div>[object Object], nickname "Wash"</div>
```

#### Tagless Output

Content can be rendered without an enclosing tag by wrapping it in HTX's dummy tag, `<:>...</:>`. This is
useful within a control loop or conditional when output is desired with no enclosing tag. (Note: dummy tags
may not contain any child tags.)

```html
<!-- Template -->
<div class='names'>
  for (let person of this.people) {
    <:>${person.name}...</:>
  }
</div>

<!-- Result -->
<div class='names'>
  Mal...Zoe...Jayne...
</div>
```

#### Keys

For optimal performance when rendering content via a loop, a unique key can be provided for each item by way
of an `htx-key` attribute (those familiar with JSX will recognize this functionality). This attribute is not
included as an actual attribute on the resulting DOM node, but is leveraged by the [JavaScript
Library](#javascript-library) to optimize the performance of DOM updates.

```html
<ul class='people-list'>
  for (let person of this.people) {
    <li class='person ${person.role}' htx-key='${person.id}'>
      ${person.name}
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
<li class='person ${person.role}'>...</li>

<!-- Result when person.role is 'captain' -->
<li class='person captain'>...</li>
```

One special case is made for boolean(ish) values: if the attribute value is strictly JavaScript (no static
parts to it) and evaluates to `true`, `false`, `null`, or `undefined`, the attribute is treated as a boolean
attribute. Example:

```html
<!-- Template -->
<li class='person' selected='${person.selected}'>...</div>

<!-- Result when person.selected === true -->
<li class='person' selected>...</div>

<!-- Result when person.selected === false, null, or undefined -->
<li class='person'>...</div>
```

## Compiler

The HTX compiler is written in Ruby. That being said, since HTX templates are valid HTML documents, porting
to other languages should be fairly straightforward considering an HTML parsing library can be leveraged to
do the bulk of the heavy lifting (as is the case with the Ruby compiler, which leverages Nokogiri).

Calling the compiler is simple:

```ruby
path = '/components/people.htx'
content = File.read("/assets#{path}")

HTX.compile(path, content)

# Or to attach to a custom object instead of `window`:
HTX.compile(path, content, assign_to: 'myTemplates')
```

Result:

```javascript
window['/components/people.htx'] = function(htx) {
  htx.node('div', 'class', `people`, 4)
    htx.node('h1', 8); htx.node(this.title, 14); htx.close()

    htx.node('ul', 'class', `people-list`, 16)
      for (let person of this.people) {
        htx.node('li', 'class', `person ${person.role}`, 20)
          htx.node(person.name, 26)
        htx.close()
      }
  htx.close(2)
}

// If `assign_to` is specified:
myTemplates['/components/people.htx'] = function(htx) {
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

The HTX Component JavaScript library is small and optional part of HTX. It provides a simple `HTXComponent`
class designed to be extended by various component classes.

```javascript
class People extends HTXComponent {
  constructor(peopleList) {
    super('/components/people.htx')

    this.peopleList = peopleList
  }

  // ...
}
```

The constructor takes the name of the template function for the component. The class provides `mount` and
`render` functions to be used for insertion into the DOM and refreshing when changes occur, respectively.
(Note: `mount` renders and inserts into the DOM and should be called once for the initial rendering of the
component; `render` should be called on a mounted component whenever it needs to be refreshed.)

An optional `didRender` function can be implemented by the child component class, which will be called
whenever a render occurs. It is passed one argument that is `true` on the initial render and `false`
thereafter.

```javascript
let crew = {
  title: 'Serenity Crew',
  people: [
    {role: 'captain', name: 'Mal'},
    {role: 'first-mate', name: 'Zoe'},
    {role: 'mercenary', name: 'Jayne'},
  ],
}

let people = new People(crew.people)
people.mount(document.body, 'prepend') // Initial rendering and insertion into the DOM

crew.people.push({role: 'pilot', name: 'Hoban Washburne'})
people.render() // The component's `render` function must be called to refresh the DOM.
```

## Performance

As stated previously, HTX is both faster and more memory efficient than JSX. Instead of building a virtual
DOM and diff-ing it against the real DOM, HTX walks the actual DOM and updates it on the fly. Doing so is
very performant and has almost no memory overhead.

Performance has been measured with an adaptation of the DBMonster web app. The average of 10 runs each
running on a MacBook Pro, 3.1GHz i7, 16GB memory are as follows:

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
