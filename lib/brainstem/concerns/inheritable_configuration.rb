require 'active_support/concern'
require 'brainstem/dsl/configuration'

module Brainstem
  module Concerns
    module InheritableConfiguration
      extend ActiveSupport::Concern

      module ClassMethods
        def configuration
          @configuration ||= begin
            if superclass.respond_to?(:configuration)
              DSL::Configuration.new(superclass.configuration)
            else
              DSL::Configuration.new
            end
          end
        end

        def clear_configuration!
          @configuration = nil
        end
      end

      def configuration
        self.class.configuration
      end
    end
  end
end
