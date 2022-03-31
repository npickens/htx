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

  context(HTX::TextParser, '#statement?') do
    test('returns true if text contains open curly brace')                { assert_statement('{') }
    test('returns true if text contains close curly brace')               { assert_statement('}') }
    test('returns true if text contains plain assignment')                { assert_statement('i = 1') }
    test('returns true if text contains addition assignment')             { assert_statement('i += 1') }
    test('returns true if text contains bitwise AND assignment')          { assert_statement('i &= 1') }
    test('returns true if text contains bitwise OR assignment')           { assert_statement('i |= 1') }
    test('returns true if text contains bitwise XOR assignment')          { assert_statement('i ^= 1') }
    test('returns true if text contains division assignment')             { assert_statement('i /= 2') }
    test('returns true if text contains exponentiation assignment')       { assert_statement('i **= 2') }
    test('returns true if text contains left shift assignment')           { assert_statement('i <<= 1') }
    test('returns true if text contains logical AND assignment')          { assert_statement('i &&= 1') }
    test('returns true if text contains logical nullish assignment')      { assert_statement('i ??= 1') }
    test('returns true if text contains logical OR assignment')           { assert_statement('i ||= 1') }
    test('returns true if text contains multiplication assignment')       { assert_statement('i *= 2') }
    test('returns true if text contains remainder assignment')            { assert_statement('i %= 2') }
    test('returns true if text contains subtraction assignment')          { assert_statement('i -= 1') }
    test('returns true if text contains unsigned right shift assignment') { assert_statement('i >>>= 1') }
    test('returns true if text contains increment operator')              { assert_statement('i++') }
    test('returns true if text contains decrement operator')              { assert_statement('i--') }
    test('returns true if text contains function call')                   { assert_statement('func()') }
    test('returns true if text contains object reference')                { assert_statement('obj[i]') }

    test('returns false if statement is inside an interpolation') { refute_statement('${i = 1}') }
    test('returns false if text contains semicolon')              { refute_statement(';') }
    test('returns false if text contains open parenthesis')       { refute_statement('(') }
    test('returns false if text contains close parenthesis')      { refute_statement(')') }
  end

  ##########################################################################################################
  ## #raw?                                                                                                ##
  ##########################################################################################################

  context(HTX::TextParser, '#raw?') do
    test('returns true if text contains single interpolation') do
      assert(parse('${function() { return "Hello, World!" }()}').raw?)
    end

    test('returns true if text contains single interpolation with whitespace') do
      assert(parse('  ${function() { return "Hello, World!" }()}  ').raw?)
    end

    test('returns false if text contains multiple interpolations') do
      refute(parse('${function() { return "Hello" }()}${", World!"}').raw?)
    end

    test('returns false if text contains single interpolation with text') do
      refute(parse('${function() { return "Hello" }()}, World!').raw?)
    end
  end

  ##########################################################################################################
  ## #template?                                                                                           ##
  ##########################################################################################################

  context(HTX::TextParser, '#template?') do
    test('returns true if text contains regular text') do
      assert(parse('Hello, World!').template?)
    end

    test('returns true if text contains regular text and an interpolation') do
      assert(parse('Hello, ${`World!`}').template?)
    end

    test('returns true if text contains single empty interpolation') do
      assert(parse('${}').template?)
    end
  end

  ##########################################################################################################
  ## Formatting                                                                                           ##
  ##########################################################################################################

  context(HTX::TextParser, '#parse') do
    test('outdents template string') do
      text = "`
        line 1
          line 2
      `"

      assert_equal("`\nline 1\n  line 2\n`", parse(text).content)
    end

    test('does not outdent single interpolation') do
      text = "${
        line 1
          line 2
      }"

      assert_equal("\n        line 1\n          line 2\n      ", parse(text).content)
    end
  end
end
