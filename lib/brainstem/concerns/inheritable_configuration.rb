module Brainstem
  module Concerns
    module InheritableConfiguration
      extend ActiveSupport::Concern
  
      module ClassMethods
        def configuration
          @configuration ||= begin
            if superclass.respond_to?(:configuration)
              Configuration.new(superclass.configuration)
            else
              Configuration.new
            end
          end
        end
      end

      class Configuration
        def initialize(parent_configuration = nil)
          @parent_configuration = parent_configuration || {}
          @storage = {}
        end

        def [](key)
          get!(key)
        end

        def []=(key, value)
          if get!(key).is_a?(Configuration)
            raise 'You cannot override a nested value'
          else
            @storage[key] = value
          end
        end

        def nest(key)
          get!(key)
          @storage[key] ||= Configuration.new
        end

        private

        def get!(key)
          @storage[key] || begin
            if @parent_configuration[key].is_a?(Configuration)
              @storage[key] = Configuration.new(@parent_configuration[key])
            else
              @parent_configuration[key]
            end
          end
        end
      end
    end
  end
end