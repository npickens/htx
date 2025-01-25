# frozen_string_literal: true

require('htx')
require('minitest/autorun')
require_relative('test_helper')

class TextParserTest < Minitest::Test
  include(TestHelper)

  def parse(text, statement_allowed: true)
    parser = HTX::TextParser.new(text, statement_allowed: statement_allowed)
    parser.parse

    parser
  end

  ##########################################################################################################
  ## #statement?                                                                                          ##
  ##########################################################################################################

  def assert_statement(text)
    assert(parse("A statement: #{text}", statement_allowed: true).statement?)
  end

  def refute_statement(text)
    refute(parse("Not a statement: #{text}", statement_allowed: true).statement?)
  end

  test('#statement? returns true for an open curly brace')                  { assert_statement('{') }
  test('#statement? returns true for a close curly brace')                  { assert_statement('}') }
  test('#statement? returns true for a plain assignment')                   { assert_statement('i = 1') }
  test('#statement? returns true for an addition assignment')               { assert_statement('i += 1') }
  test('#statement? returns true for a bitwise AND assignment')             { assert_statement('i &= 1') }
  test('#statement? returns true for a bitwise OR assignment')              { assert_statement('i |= 1') }
  test('#statement? returns true for a bitwise XOR assignment')             { assert_statement('i ^= 1') }
  test('#statement? returns true for a division assignment')                { assert_statement('i /= 2') }
  test('#statement? returns true for an exponentiation assignment')         { assert_statement('i **= 2') }
  test('#statement? returns true for a left shift assignment')              { assert_statement('i <<= 1') }
  test('#statement? returns true for a logical AND assignment')             { assert_statement('i &&= 1') }
  test('#statement? returns true for a logical nullish assignment')         { assert_statement('i ??= 1') }
  test('#statement? returns true for a logical OR assignment')              { assert_statement('i ||= 1') }
  test('#statement? returns true for a multiplication assignment')          { assert_statement('i *= 2') }
  test('#statement? returns true for a remainder assignment')               { assert_statement('i %= 2') }
  test('#statement? returns true for a subtraction assignment')             { assert_statement('i -= 1') }
  test('#statement? returns true for an unsigned right shift assignment')   { assert_statement('i >>>= 1') }
  test('#statement? returns true for an increment operator')                { assert_statement('i++') }
  test('#statement? returns true for a decrement operator')                 { assert_statement('i--') }
  test('#statement? returns true for a function call')                      { assert_statement('func()') }
  test('#statement? returns true for an object reference')                  { assert_statement('obj[i]') }

  test('#statement? returns false for a statement inside an interpolation') { refute_statement('${i = 1}') }
  test('#statement? returns false for a semicolon')                         { refute_statement(';') }
  test('#statement? returns false for an open parenthesis')                 { refute_statement('(') }
  test('#statement? returns false for a close parenthesis')                 { refute_statement(')') }

  ##########################################################################################################
  ## #raw?                                                                                                ##
  ##########################################################################################################

  test('#raw? returns true if text contains single interpolation') do
    assert(parse('${function() { return "Hello, World!" }()}').raw?)
  end

  test('#raw? returns true if text contains single interpolation with whitespace') do
    assert(parse('  ${function() { return "Hello, World!" }()}  ').raw?)
  end

  test('#raw? returns false if text contains multiple interpolations') do
    refute(parse('${function() { return "Hello" }()}${", World!"}').raw?)
  end

  test('#raw? returns false if text contains single interpolation with text') do
    refute(parse('${function() { return "Hello" }()}, World!').raw?)
  end

  ##########################################################################################################
  ## #template?                                                                                           ##
  ##########################################################################################################

  test('#template? returns true if text contains regular text') do
    assert(parse('Hello, World!').template?)
  end

  test('#template? returns true if text contains regular text and an interpolation') do
    assert(parse('Hello, ${`World!`}').template?)
  end

  test('#template? returns true if text contains single empty interpolation') do
    assert(parse('${}').template?)
  end

  ##########################################################################################################
  ## Formatting                                                                                           ##
  ##########################################################################################################

  test('#parse outdents template string') do
    text = "`
      line 1
        line 2
    `"

    assert_equal("`\nline 1\n  line 2\n`", parse(text).content)
  end

  test('#parse does not outdent single interpolation') do
    text = "${
      line 1
        line 2
    }"

    assert_equal("\n      line 1\n        line 2\n    ", parse(text).content)
  end
end
