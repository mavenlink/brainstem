module Brainstem
  module DSL
    class Conditional
      attr_reader :name, :type, :action, :description

      def initialize(name, type, action, description)
        @name = name
        @type = type
        @action = action
        @description = description
      end

      def matches?(model, helper_instance = Object.new, conditional_cache = {})
        case type
          when :model
            helper_instance.instance_exec(model, &action)
          when :request
            conditional_cache.fetch(name) { conditional_cache[name] = helper_instance.instance_exec(&action) }
          else
            raise "Unknown Brainstem Conditional type #{type}"
        end
      end
    end
  end
end
