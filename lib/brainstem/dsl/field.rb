module Brainstem
  module DSL
    class Field
      attr_reader :name, :type, :description, :conditionals, :options

      def initialize(name, type, description, options)
        @name = name
        @type = type
        @description = description
        @conditionals = [options[:if]].flatten.compact
        @options = options
      end

      def conditional?
        conditionals.length > 0
      end

      def method_name
        if options[:dynamic]
          nil
        else
          (options[:via].presence || name).to_s
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

      def conditionals_match?(model, presenter_conditionals, helper_instance = Object.new, conditional_cache = { model: {}, request: {} })
        return true unless conditional?

        conditionals.all? { |conditional|
          presenter_conditionals[conditional].matches?(model, helper_instance, conditional_cache)
        }
      end
    end
  end
end
