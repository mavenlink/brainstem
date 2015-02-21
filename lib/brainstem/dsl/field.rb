module Brainstem
  module DSL
    class Field
      attr_reader :name, :type, :description, :options

      def initialize(name, type, description, options)
        @name = name
        @type = type
        @description = description
        @options = options
      end

      def method_name
        if options[:dynamic]
          nil
        else
          options[:via].presence || name
        end
      end

      def run_on(model, helper_instance = Object.new)
        if options[:dynamic]
          proc = options[:dynamic]
          if proc.arity > 0
            helper_instance.instance_exec(model, &proc)
          else
            helper_instance.instance_exec(&proc)
          end
        else
          model.send(method_name)
        end
      end
    end
  end
end
