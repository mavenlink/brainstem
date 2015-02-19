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

      def run_on(model)
        if options[:dynamic]
          if options[:dynamic].arity > 0
            options[:dynamic].call(model)
          else
            options[:dynamic].call
          end
        else
          model.send(method_name)
        end
      end
    end
  end
end
