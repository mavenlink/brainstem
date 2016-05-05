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
        if options[:dynamic] && (!options[:lookup] || context[:models].size == 1)
          proc = options[:dynamic]
          if proc.arity == 1
            helper_instance.instance_exec(model, &proc)
          else
            helper_instance.instance_exec(&proc)
          end
        elsif options[:lookup]
          run_on_with_lookup(model, context, helper_instance)
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

      private

      def run_on_with_lookup(model, context, helper_instance)
        context[:lookup][:associations][name] ||= begin
          proc = options[:lookup]
          lookup = helper_instance.instance_exec(context[:models], &proc)
          if !options[:lookup_fetch].present? && !lookup.respond_to?(:[])
            raise(StandardError, 'Brainstem expects the return result of the `lookup` to be a Hash since it must respond to [] in order to access the model\'s assocation(s). Default: lookup_fetch: lambda { |lookup, model| lookup[model.id] }`')
          end

          lookup
        end

        if options[:lookup_fetch]
          proc = options[:lookup_fetch]
          helper_instance.instance_exec(context[:lookup][:associations][name], model, &proc)
        else
          context[:lookup][:associations][name][model.id]
        end
      end
    end
  end
end
