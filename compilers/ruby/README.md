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
as strings to the `HTX.compile` method (all other arguments are optional):

```ruby
path = '/components/crew.htx'
template = File.read(File.join('some/asset/dir', path))

HTX.compile(path, template)

# window['/components/crew.htx'] = function(htx) {
#   // ...
# }

HTX.compile(path, template, assign_to: 'myTemplates')

# myTemplates['/components/crew.htx'] = function(htx) {
#   // ...
# }
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/npickens/htx.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
