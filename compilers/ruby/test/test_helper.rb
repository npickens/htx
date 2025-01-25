# frozen_string_literal: true

require('minitest/autorun')

module TestHelper
  INSPECT_SPLIT = /@(?=\w+=)/.freeze
  INSPECT_JOIN = "\n@"

  MINITEST_TEST_METHOD_REGEX = /^test_/.freeze

  @test_names = {}
  @test_numbers = {}

  class << self
    attr_accessor(:test_names)
    attr_accessor(:test_numbers)
  end

  # Run a specific test by its auto-generated number (shown in failure output). Test order is still
  # randomized, but a test's number is consistent across runs so long as tests aren't added, removed, or
  # renamed.
  #
  #   Example: bin/test 123
  #
  if ARGV[0]&.match?(/^\d+$/)
    at_exit do
      if (test_name = TestHelper.test_names[ARGV[0].to_i])
        ARGV[0] = test_name
        ARGV.unshift('-n')
      else
        abort("Test number #{ARGV[0]} doesn't exist")
      end
    end
  end

  ##########################################################################################################
  ## Testing                                                                                              ##
  ##########################################################################################################

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def test(description, &block)
      method_name = "#{name.chomp('Test')}#{' ' unless %w[# .].include?(description[0])}#{description}"
      test_methods << method_name

      if TestHelper.test_numbers.key?(method_name)
        raise("Duplicate test name: #{method_name.inspect}")
      end

      TestHelper.test_names[TestHelper.test_names.size + 1] = method_name
      TestHelper.test_numbers[method_name] = TestHelper.test_numbers.size + 1

      define_method(method_name, &block)
    end

    def test_methods
      @test_methods ||= []
    end

    # Override of Minitest::Runnable.methods_matching
    def methods_matching(regex)
      regex == MINITEST_TEST_METHOD_REGEX ? test_methods : super
    end
  end

  ##########################################################################################################
  ## Helpers                                                                                              ##
  ##########################################################################################################

  def assert_inspect(expected, actual)
    assert_equal(
      expected.split(INSPECT_SPLIT).join(INSPECT_JOIN),
      actual.inspect.split(INSPECT_SPLIT).join(INSPECT_JOIN)
    )
  end

  ##########################################################################################################
  ## Minitest                                                                                             ##
  ##########################################################################################################

  class Minitest::Result
    def location
      super.delete_prefix("#{class_name}#").prepend("[##{TestHelper.test_numbers[self.name]}] ")
    end
  end
end
