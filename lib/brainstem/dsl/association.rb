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

      def run_on(model, context, helper_instance = Object.new)
        if options[:dynamic]
          proc = options[:dynamic]
          if proc.arity > 0
            helper_instance.instance_exec(model, &proc)
          else
            helper_instance.instance_exec(&proc)
          end
        elsif options[:lookup]
          proc = options[:lookup]
          context[:lookup][:associations][name] ||= helper_instance.instance_exec(context[:models], &proc)
          if options[:lookup_fetch]
            proc = options[:lookup_fetch]
            helper_instance.instance_exec(context[:lookup][:associations][name], model, &proc)
          else
            context[:lookup][:associations][name][model.id]
          end
        else
          model.send(method_name)
        end
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
