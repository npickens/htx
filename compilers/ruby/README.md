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

To compile an HTX template, pass a name (conventionally the path of the template file) and template as
strings to the `HTX.compile` method:

```ruby
path = '/my/hot/template.htx'
template = File.read(File.join('some/asset/dir', path))

HTX.compile(path, template)

# Or to attach to a custom object instead of `window`:
HTX.compile(path, template, assign_to: 'myTemplates')

# Result:
#
#   window['/my/hot/template.htx'] = function(htx) {
#     ...
#   }
#
# If `assign_to` is specified:
#
#   myTemplates['/components/people.htx'] = function(htx) {
#     // ...
#   }
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/npickens/htx.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
