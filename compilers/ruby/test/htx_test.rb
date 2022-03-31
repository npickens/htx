# frozen_string_literal: true

require('htx')
require('minitest/autorun')
require_relative('test_helper')

class HTXTest < Minitest::Test
  include(TestHelper)

  ##########################################################################################################
  ## ::compile                                                                                            ##
  ##########################################################################################################

  context(HTX, '::compile') do
    test('creates a Template instance and calls #compile on it') do
      mock = MiniTest::Mock.new
      mock.expect(:compile, nil)

      HTX::Template.stub(:new, mock) do
        HTX.compile('/template.htx', '<div>Hello, World!</div>')
      end

      mock.verify
    end
  end

  ##########################################################################################################
  ## ::new                                                                                                ##
  ##########################################################################################################

  context(HTX, '::new') do
    test('warns about being deprecated and creates a Template instance') do
      warning = nil
      instance = false

      HTX.stub(:warn, ->(message) { warning = message }) do
        HTX::Template.stub(:new, ->(_, __) { instance = true }) do
          HTX.new('foo', 'bar')
        end
      end

      assert_equal('HTX.new is deprecated. Please use HTX::Template.new instead.', warning)
      assert(instance, 'Expected Template.new to be called')
    end
  end
end
