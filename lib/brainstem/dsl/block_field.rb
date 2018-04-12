require 'brainstem/dsl/configuration'
require 'brainstem/dsl/field'

module Brainstem
  module DSL
    class BlockField < Field
      attr_reader :configuration

      delegate :to_h, :keys, :has_key?, :each, to: :configuration

      def initialize(name, type, options, parent_field = nil)
        super(name, type, options)
        @parent_field = parent_field
      end

      def configuration
        @configuration ||= begin
          if @parent_field && @parent_field.respond_to?(:configuration)
            DSL::Configuration.new(@parent_field.configuration)
          else
            DSL::Configuration.new
          end
        end
      end

      def [](key)
        configuration[key]
      end

      def run_on(model, context, helper_instance = Object.new)
        raise NotImplementedError.new("Override this method in a sub class")
      end

      def self.for(name, type, options, parent_field = nil)
        case type.to_s
          when 'array'
            DSL::ArrayBlockField.new(name, type, options, parent_field)
          when 'hash'
            DSL::HashBlockField.new(name, type, options, parent_field)
          else
            raise "Unknown Brainstem Block Field type encountered: #{type}"
        end
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
        elsif options[:via]
          model.send(options[:via])
        else
          raise "Block field #{name} can only be evaluated if :dynamic, :lookup, :via options are specified."
        end
      end

      def use_parent_value?(field)
        return true unless field.options.has_key?(:use_parent_value)

        field.options[:use_parent_value]
      end
    end
  end
end
