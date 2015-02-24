module Brainstem
  module DSL
    class Association
      attr_reader :name, :target_class, :description, :options

      def initialize(name, target_class, description, options)
        @name = name
        @target_class = target_class
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

      def brainstem_key
        @brainstem_key ||= begin
          if options[:brainstem_key].present?
            options[:brainstem_key].to_sym
          else
            if polymorphic?
              nil
            else
              (options[:sti_uses_base] ? target_class.base_class : target_class).to_s.tableize.to_sym
            end
          end
        end
      end

      def run_on(model, helper_instance = Object.new)
        options[:dynamic] ? helper_instance.instance_exec(model, &options[:dynamic]) : model.send(method_name)
      end

      def load_records_into_hash!(models, record_hash)
        record_hash[brainstem_key] ||= [] if brainstem_key

        models.each do |model|
          association_models = Array(run_on(model))

          if brainstem_key
            record_hash[brainstem_key] += association_models
          else
            # Polymorphic associations' keys must be figured out now.
            association_models.each do |model|
              key = (options[:sti_uses_base] ? model.class.base_class : model.class).to_s.tableize.to_sym
              record_hash[key] ||= []
              record_hash[key] << model
            end
          end
        end
      end

      def polymorphic?
        target_class == :polymorphic
      end
    end
  end
end
