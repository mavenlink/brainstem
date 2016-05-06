module Brainstem
  module Concerns
    module Lookup
      extend ActiveSupport::Concern

      def run_on_with_lookup(model, context, helper_instance)
        context[:lookup][key_for_lookup][name] ||= begin
          proc = options[:lookup]
          lookup = helper_instance.instance_exec(context[:models], &proc)
          if !options[:lookup_fetch].present? && !lookup.respond_to?(:[])
            raise(StandardError, 'Brainstem expects the return result of the `lookup` to be a Hash since it must respond to [] in order to access the model\'s assocation(s). Default: lookup_fetch: lambda { |lookup, model| lookup[model.id] }`')
          end

          lookup
        end

        if options[:lookup_fetch]
          proc = options[:lookup_fetch]
          helper_instance.instance_exec(context[:lookup][key_for_lookup][name], model, &proc)
        else
          context[:lookup][key_for_lookup][name][model.id]
        end
      end

      def key_for_lookup
        raise(StandardError 'Implement `key_for_lookup` when including Lookup Module.')
      end
    end
  end
end