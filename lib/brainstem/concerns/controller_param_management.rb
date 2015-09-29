# Provide `brainstem_model_name` and `brainstem_plural_model_name` in controllers for use when accessing the `params` hash.

module Brainstem
  module Concerns
    module ControllerParamManagement
      extend ActiveSupport::Concern

      included do
        class_attribute :brainstem_plural_model_name, :brainstem_model_name,
                        instance_accessor: false, instance_reader: false, instance_writer: false
      end

      def brainstem_model_name
        self.class.brainstem_model_name.to_s.presence || controller_name.singularize
      end

      def brainstem_plural_model_name
        self.class.brainstem_plural_model_name.to_s.presence || brainstem_model_name.pluralize
      end
    end
  end
end