# frozen_string_literal: true

require('minitest')

module TestHelper
  MINITEST_TEST_METHOD_REGEX = /^test_/.freeze

  ##########################################################################################################
  ## Testing                                                                                              ##
  ##########################################################################################################

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def context(*contexts, &block)
      contexts.each { |c| context_stack << c.to_s }
      block.call
      context_stack.pop(contexts.size)
    end

    def test(description, &block)
      method_name = "#{context_string} #{description}"
      test_methods << method_name

      define_method(method_name, &block)
    end

    def context_stack
      @context_stack ||= []
    end

    def test_methods
      @test_methods ||= []
    end

    def context_string
      context_stack.each_with_object(+'').with_index do |(context, str), i|
        next_item = context_stack[i + 1]

        str << context
        str << ' ' unless !next_item || next_item[0] == '#' || next_item.start_with?('::')
      end
    end

    # Override of Minitest::Runnable.methods_matching
    def methods_matching(regex)
      regex == MINITEST_TEST_METHOD_REGEX ? test_methods : super
    end
  end

  ##########################################################################################################
  ## Minitest                                                                                             ##
  ##########################################################################################################

  class Minitest::Result
    def location
      super.delete_prefix("#{self.class_name}#")
    end
  end
end
