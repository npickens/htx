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
      mock = Minitest::Mock.new
      mock.expect(:compile, nil)

      HTX::Template.stub(:new, mock) do
        HTX.compile('/template.htx', '<div>Hello, World!</div>')
      end

      mock.verify
    end
  end
end
