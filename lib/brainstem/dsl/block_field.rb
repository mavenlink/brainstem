require 'brainstem/dsl/configuration'
require 'brainstem/dsl/field'

module Brainstem
  module DSL
    class BlockField < Field
      attr_reader :configuration

      def initialize(name, type, options)
        super
        @configuration = DSL::Configuration.new
      end

      def run_on(model, context, helper_instance = Object.new)
        raise NotImplementedError.new("Override this method in a sub class")
      end

      def self.for(name, type, options)
        case type.to_s
          when 'array'
            DSL::ArrayBlockField.new(name, type, options)
          when 'hash'
            DSL::HashBlockField.new(name, type, options)
          else
            raise "Unknown Brainstem Block Field type encountered: #{type}"
        end
      end

      def use_parent_value?(field)
        return true unless field.options.has_key?(:use_parent_value)

        field.options[:use_parent_value]
      end
    end
  end
end
