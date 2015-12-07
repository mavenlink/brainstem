require 'active_support/concern'

# Provide `brainstem_model_name` and `brainstem_plural_model_name` in
# controllers for use when accessing the `params` hash.

module Brainstem
  module Concerns
    module ControllerParamManagement
      extend ActiveSupport::Concern

      def brainstem_model_name
        self.class.brainstem_model_name.to_s
      end

      def brainstem_plural_model_name
        self.class.brainstem_plural_model_name.to_s
      end

      module ClassMethods
        def brainstem_model_name
          @brainstem_model_name ||= controller_name.singularize
        end

        def brainstem_plural_model_name
          @brainstem_plural_model_name ||= self.brainstem_model_name.pluralize
        end

        def brainstem_model_name=(name)
          @brainstem_model_name = name
        end

        def brainstem_plural_model_name=(name)
          @brainstem_plural_model_name = name
        end
      end
    end
  end
end
