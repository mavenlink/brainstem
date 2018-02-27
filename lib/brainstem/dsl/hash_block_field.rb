require 'brainstem/dsl/configuration'
require 'brainstem/dsl/block_field'

module Brainstem
  module DSL
    class HashBlockField < BlockField
      def run_on(model, context, helper_instance = Object.new)
        evaluated_model = nil
        evaluated_model = evaluate_value_on(model, context, helper_instance) if executable?(model)

        result = {}

        configuration.each do |field_name, field|
          next unless field.presentable?(model, context)

          model_for_field = (executable?(model) && use_parent_value?(field)) ? evaluated_model : model
          result[field_name] = field.run_on(model_for_field, context, context[:helper_instance])
        end

        result
      end

      private

      EXECUTABLE_OPTIONS = [:dynamic, :via, :lookup]
      private_constant :EXECUTABLE_OPTIONS

      def executable?(model)
        (options.keys & EXECUTABLE_OPTIONS).present? || model.respond_to?(name.to_sym)
      end
    end
  end
end
