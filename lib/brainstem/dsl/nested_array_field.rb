require 'brainstem/dsl/configuration'
require 'brainstem/dsl/field'

module Brainstem
  module DSL
    class NestedArrayField < Field
      attr_reader :configuration

      def initialize(name, type, options)
        super
        @configuration = DSL::Configuration.new
      end

      def run_on(model, context, helper_instance = Object.new)
        evaluated_models = evaluate_value_on(model, context, helper_instance)

        evaluated_models.map do |evaluated_model|
          result = {}

          configuration.each do |field_name, field|
            if field.presentable?(model, context)
              model_for_field = use_parent_value?(field) ? evaluated_model : model

              result[field_name] = field.run_on(model_for_field, context, context[:helper_instance])
            end
          end

          result
        end
      end

      private

      def use_parent_value?(field)
        return true unless field.options.has_key?(:use_parent_value)

        field.options[:use_parent_value]
      end
    end
  end
end
