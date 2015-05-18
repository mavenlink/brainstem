module Brainstem
  module DSL
    class Association
      attr_reader :name, :target_class, :description, :options

      def initialize(name, target_class, description, options)
        @name = name.to_s
        @target_class = target_class
        @description = description
        @options = options
      end

      def method_name
        if options[:dynamic]
          nil
        else
          (options[:via].presence || name).to_s
        end
      end

      def run_on(model, helper_instance = Object.new)
        options[:dynamic] ? helper_instance.instance_exec(model, &options[:dynamic]) : model.send(method_name)
      end

      def polymorphic?
        target_class == :polymorphic
      end

      def always_return_ref_with_sti_base?
        options[:always_return_ref_with_sti_base]
      end
    end
  end
end
