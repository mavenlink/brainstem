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
        dynamic_proc = options[:dynamic]
        lookup_proc = options[:lookup]

        if dynamic_proc
          if dynamic_proc.arity > 0
            helper_instance.instance_exec(model, &dynamic_proc)
          else
            helper_instance.instance_exec(&dynamic_proc)
          end
        elsif lookup_proc
          context[:lookup][:associations][name] ||= helper_instance.instance_exec(context[:models], &lookup_proc)
          context[:lookup][:associations][name][model.id]
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
