# HTX Ruby Compiler

HTX templates are compiled to JavaScript before being used. This library provides a Ruby implementation of
the compiler. For more information on HTX, see the main [README](https://github.com/npickens/htx).

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

HTX templates can be compiled to either a JavaScript module format or an IIFE assigned to a property on
either `globalThis` or a custom object. To compile as a module:

```ruby
path = '/components/crew.htx'
content = File.read("/assets#{path}")

HTX.compile(path, content, as_module: true, import_path: 'vendor/htx.js')
# => "import * as HTX from 'vendor/htx.js'
#
#     ...
#
#     export function Template { ... }"
#
```

Note that with the module format the name of the template does not appear anywhere in its compiled form, but
is still used/useful for tracking down errors when compilation is handled by an overall asset management
system (such as [Darkroom](https://github.com/npickens/darkroom)).

To compile to an IIFE assigned to a custom object:

```ruby
HTX.compile(path, content, as_module: false, assign_to: 'myTemplates')
# => "myTemplates['/components/crew.htx'] = ..."
```

Options can be configured globally so they don't have to be passed to `HTX.compile` every time:

```ruby
HTX.as_module = true              # Default: false
HTX.import_path = 'vendor/htx.js' # Default: "/htx/htx.js"
HTX.assign_to = 'myTemplates'     # Default: "globalThis"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/npickens/htx.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
