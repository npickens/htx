# HTX Ruby Compiler

HTX templates are compiled to JavaScript before being used. This library provides a Ruby implementation of
the compiler. For more information on HTX, see
[https://github.com/npickens/htx](https://github.com/npickens/htx).

## Installation

Add this line to your Gemfile:

```ruby
gem('htx')
```

Or install manually on the command line:

```bash
gem install htx
```

## Usage

To compile an HTX template, pass a name (conventionally the path of the template file) and template content
as strings to the `HTX.compile` method (all other arguments are optional). By default, compiled templates
are a function assigned to the `globalThis` object:

```ruby
path = '/components/crew.htx'
template = File.read(File.join('some/asset/dir', path))

HTX.compile(path, template)
# => "globalThis['/components/crew.htx'] = ..."

HTX.compile(path, template, assign_to: 'myTemplates')
# => "myTemplates['/components/crew.htx'] = ..."
```

The above format is the default due to it historically being the only option. Alternatively templates can be
compiled as a JavaScript module:

```ruby
path = '/components/crew.htx'
template = File.read(File.join('some/asset/dir', path))

HTX.compile(path, template, as_module: true)
# => "import * as HTX from '/htx/htx.js'
#
#     // ...
#
#     export function Template { ... }"
#

HTX.compile(path, template, as_module: true, import_path: 'vendor/htx.js')
# => "import * as HTX from 'vendor/htx.js'
#
#     // ...
#
#     export function Template { ... }"
#
```

Note that with the module format the name of the template does not appear anywhere in the output, but is
still used/useful for tracking down errors when compilation is handled by an overall asset management system
(such as [Darkroom](https://github.com/npickens/darkroom)).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/npickens/htx.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
