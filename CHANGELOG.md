# HTX Changelog

## Upcoming (Unreleased)

* Stop requiring `<template>` tag to wrap JavaScript in some places
* Add package.json and basic tests
* Restore deprecated attributes in Ruby compiler mixed-case SVG map
* Include deprecated case-sensitive SVG tags/attributes in Ruby compiler

## 1.0.1 (2025 January 21)

* Add inspect method to Ruby compiler Template class
* **Set 'checked' property on input elements instead of calling `setAttribute`**
* Remove no-longer-used Renderer constructor parameters
* Simplify rotation of dynamic index objects by leveraging WeakRef

## 1.0.0 (2024 May 22)

* **Update Ruby compiler to require Ruby 3.0.0 or later**
* **Fix input values not updating after initial rendering**
* Fix rendering of templates with childless root node
* Bring Ruby compiler SVG mixed-case attribute list up to date
* **Remove support for concatenating deprecation code from build script**
* **Remove support for top-level `HTX` variable**
* **Remove support for `HTXComponent` variable**
* **Remove support for instantiating a template with `new HTX(...)`**
* **Remove support for passing template name to Component constructor**
* **Compile children of `<template>` tags but not the tag itself**

## 0.1.1 (2023 July 15)

* Simplify and fix issues with deprecation handling and warnings
* **Add option to Ruby compiler to compile templates as JavaScript modules**

## 0.1.0 (2023 July 7)

* **Rework how templates get rendered to allow direct instantiation**
* Remove unnecessary non-null check in while loop of close function
* Update Ruby compiler to use Nokogiri's HTML5 parser when available
* **Allow 'class' attribute values to be arrays and ignore falsey elements**
* **Remove deprecated explicit indent option from Ruby compiler**
* **Remove deprecated static `HTX.render` function**
* Fix check for template's existence when referenced by name
* **Assign template functions to `globalThis` (instead of `window`) by default**
* **Remove support for deprecated `<:>` and `<htx-text>` tags from Ruby compiler**
* **Remove deprecated `HTX.new` method from Ruby compiler**

## 0.0.9 (2022 March 31)

* **Fix bad root node variable reference in HTX**
* **Fix bad HTX instance reference in HTXComponent**

## 0.0.8 (2022 March 31)

* **Deprecate explicit indent option in Ruby compiler**
* Rewrite Ruby compiler for better statement detection and performance
* **Deprecate static HTX render function in favor of new instance method**

## 0.0.7 (2022 February 9)

* Fix childless xmlns nodes causing all subsequent nodes to use that xmlns
* **Fix mounting and rendering from within HTXComponent `didRender` callbacks**
* Allow previous dynamic node index to be garbage collected after a render
* Always reuse any existing node with a dynamic key
* Explicitly disallow attributes other than `htx-key` on `<htx-content>` tags
* **Rename `<htx-text>` tag to `<htx-content>` for a more accurate name**
* Handle re-rendering of dynamic content more robustly
* **Fix rendering of `<select>` tags when selected option changes**
* Remove unnecessary special handling of input tag attributes [was actually necessary and restored in 1.0.0
  and 1.0.1]
* **Fix closing of tags with xmlns attribute**
* Escape unescaped backticks in unquoted text nodes and attribute values

## 0.0.6 (2022 January 21)

* Lay Ruby compiler groundwork for future use of Nokogiri's HTML5 parser
* Only call render when mounting an HTXComponent if placement arg is valid
* Automatically add xmlns attribute to `<math>` and `<svg>` tags that lack it
* **Properly handle all tags that have an xmlns attribute**
* **Rename `<:>` tag to `<htx-text>` for better HTML parser compatibility**

## 0.0.5 (2021 June 5)

* Don't leak old nodes in static and dynamic key weak maps
* Don't coerce previously null or undefined values to text nodes
* **Allow initial render of child HTXComponent with parent already mounted**
* **Require Ruby version 2.5.8 or later for Ruby compiler gem**
* Match template's indentation in compiled output and allow override
* Properly compile tab-indented templates

## 0.0.4 (2020 April 1)

* Allow templates to be compiled to a custom object instead of `window`
* Compile tags with only whitespace text as childless
* **Run HTXComponent render callbacks after all components are rendered**
* Tweak HTXComponent mount code to improve minification
* Raise error in Ruby compiler if dummy tag contains a child tag
* Refer to `<:></:>` tags as dummy tags instead of void tags
* **Include line number in Ruby compiler error messages whenever possible**
* Reset HTXComponent `isMounting` flag when component mount is complete

## ~~0.0.3 (2020 April 1)~~

* Gem did not get built correctly, so version was yanked

## 0.0.2 (2019 October 28)

* **Use `document.body` as default mount point in HTXComponent**
* **Distribute non-minified versions of JavaScript files**
* Use object-oriented style code instead of functional in Ruby compiler
* Raise error during compilation if the template's root is malformed

## 0.0.1 (2019 July 3)

* Release initial gem
