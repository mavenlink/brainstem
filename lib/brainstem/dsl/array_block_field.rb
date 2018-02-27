require 'brainstem/dsl/configuration'
require 'brainstem/dsl/block_field'

module Brainstem
  module DSL
    class ArrayBlockField < BlockField
      def run_on(model, context, helper_instance = Object.new)
        evaluated_models = evaluate_value_on(model, context, helper_instance)

        evaluated_models.map do |evaluated_model|
          result = {}

          configuration.each do |field_name, field|
            next unless field.presentable?(model, context)

            model_for_field = use_parent_value?(field) ? evaluated_model : model
            result[field_name] = field.run_on(model_for_field, context, context[:helper_instance])
          end

          result
        end
      end
    end
  end
end
