require 'brainstem/concerns/lookup'

module Brainstem
  module DSL
    class Field
      include Brainstem::Concerns::Lookup

      attr_reader :name, :type, :conditionals, :options

      def initialize(name, type, options)
        @name = name.to_s
        @type = type.to_s
        @conditionals = [options[:if]].flatten.compact
        @options = options
      end

      def description
        options[:info].presence
      end

      def conditional?
        conditionals.length > 0
      end

      def method_name
        if options[:dynamic] || options[:lookup]
          nil
        else
          (options[:via].presence || name).to_s
        end
      end

      def optioned?(requested_optional_fields)
        !optional? || requested_optional_fields.include?(@name)
      end

      def optional?
        options[:optional]
      end

      # Please override in sub classes to compute value of field with the given arguments.
      def run_on(model, context, helper_instance = Object.new)
        evaluate_value_on(model, context, helper_instance)
      end

      def evaluate_value_on(model, context, helper_instance = Object.new)
        if options[:lookup]
          run_on_with_lookup(model, context, helper_instance)
        elsif options[:dynamic]
          proc = options[:dynamic]
          if proc.arity == 1
            helper_instance.instance_exec(model, &proc)
          else
            helper_instance.instance_exec(&proc)
          end
        else
          model.send(method_name)
        end
      end

      def presentable?(model, context)
        optioned?(context[:optional_fields]) && conditionals_match?(
          model,
          context[:conditionals],
          context[:helper_instance],
          context[:conditional_cache]
        )
      end

      def conditionals_match?(model, presenter_conditionals, helper_instance = Object.new, conditional_cache = { model: {}, request: {} })
        return true unless conditional?

        conditionals.all? { |conditional|
          presenter_conditionals[conditional].matches?(model, helper_instance, conditional_cache)
        }
      end

      private

      def key_for_lookup
        :fields
      end
    end
  end
end
