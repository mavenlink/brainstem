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

      def matches?(model, helper_instance = Object.new, conditional_cache = { model: {}, request: {} })
        case type
          when :model
            conditional_cache[:model].fetch(name) { conditional_cache[:model][name] = helper_instance.instance_exec(model, &action) }
          when :request
            conditional_cache[:request].fetch(name) { conditional_cache[:request][name] = helper_instance.instance_exec(&action) }
          else
            raise "Unknown Brainstem Conditional type #{type}"
        end
      end
    end
  end
end
