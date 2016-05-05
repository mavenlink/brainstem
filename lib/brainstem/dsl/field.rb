module Brainstem
  module DSL
    class Field
      attr_reader :name, :type, :description, :conditionals, :options

      def initialize(name, type, description, options)
        @name = name.to_s
        @type = type
        @description = description
        @conditionals = [options[:if]].flatten.compact
        @options = options
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

      def conditionals_match?(model, presenter_conditionals, helper_instance = Object.new, conditional_cache = { model: {}, request: {} })
        return true unless conditional?

        conditionals.all? { |conditional|
          presenter_conditionals[conditional].matches?(model, helper_instance, conditional_cache)
        }
      end

      private

      def run_on_with_lookup(model, context, helper_instance)
        context[:lookup][:fields][name] ||= begin
          proc = options[:lookup]
          lookup = helper_instance.instance_exec(context[:models], &proc)
          if !options[:lookup_fetch].present? && !lookup.respond_to?(:[])
            raise(StandardError, 'Brainstem expects the return result of the `lookup` to be a Hash since it must respond to [] in order to access the model\'s assocation(s). Default: lookup_fetch: lambda { |lookup, model| lookup[model.id] }`')
          end

          lookup
        end

        if options[:lookup_fetch]
          proc = options[:lookup_fetch]
          helper_instance.instance_exec(context[:lookup][:fields][name], model, &proc)
        else
          context[:lookup][:fields][name][model.id]
        end
      end
    end
  end
end
