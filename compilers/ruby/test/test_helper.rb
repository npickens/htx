# frozen_string_literal: true

unless Dir.pwd == (base_dir = File.dirname(__dir__))
  ENV['BUNDLE_GEMFILE'] = File.join(base_dir, 'Gemfile')
end

require('bundler/setup')
require('htx')
require('minitest/autorun')
require('minitest/minitest_reporter_plugin')
require('minitest/reporters')

module TestHelper
  INSPECT_SPLIT = /@(?=\w+=)/
  INSPECT_JOIN = "\n@"

  ##########################################################################################################
  ## Testing                                                                                              ##
  ##########################################################################################################

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def test(description, &block)
      @@test_count ||= 0
      @@test_count += 1

      method_name =
        "test_#{@@test_count}: " \
        "#{name.chomp('Test') unless description.match?(/^[A-Z]/)}" \
        "#{' ' unless description.match?(/^[A-Z#.]/)}" \
        "#{description}"

      define_method(method_name, &block)
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
end

module Minitest
  ENV['MT_NO_PLUGINS'] = '1'

  register_plugin('index')
  extensions << 'minitest_reporter'

  def self.plugin_index_init(options)
    options[:filter]&.sub!(/^\d+$/, '/^test_\0: /')
  end

  Reporters.use!(Reporters::ProgressReporter.new)
end
