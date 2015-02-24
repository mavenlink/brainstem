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
            options[:brainstem_key].to_s
          else
            if polymorphic?
              nil
            else
              self.class.brainstem_key_for(target_class, options[:sti_uses_base])
            end
          end
        end
      end

      def run_on(model, helper_instance = Object.new)
        options[:dynamic] ? helper_instance.instance_exec(model, &options[:dynamic]) : model.send(method_name)
      end

      def polymorphic?
        target_class == :polymorphic
      end

      def self.brainstem_key_for(klass, use_base = false)
        (use_base ? klass.base_class : klass).to_s.tableize
      end
    end
  end
end
