module Brainstem
  module Concerns
    module ErrorPresentation
      extend ActiveSupport::Concern

      # Given one or more error messages, return Brainstem-style errors, defaulting to type 'system'.
      def brainstem_system_error(*messages)
        options = messages.last.is_a?(Hash) ? messages.pop : {}
        response = { :errors => [] }
        messages.flatten.uniq.each do |message|
          response[:errors] << {
            :type => options[:type] || :system,
            :message => message
          }
        end
        response
      end

      # Given a model or models, outputs Brainstem-style errors, for example:
      #  { :errors => [{ :type => 'validation', :field => :thing_id, :message => "Thing is required" }] }
      # If given a rewrite_params hash, it will convert from an internal column name to an external name.
      # Note: you must validate models prior to passing them into this method.  It does not call `valid?` on them.
      def brainstem_model_error(object_or_objects, options = {})
        json = { :errors => [] }

        [object_or_objects].flatten.each.with_index do |object, index|
          case object
            when Hash
              attribute = object[:field] || :base
              json[:errors] << {
                :type => object[:type] || 'validation',
                :field => (options[:rewrite_params] || {}).reverse_merge(attribute => attribute).invert[attribute],
                :message => object[:message] || raise(ArgumentError, "message required")
              }
            when String
              json[:errors] << { :type => 'validation', :field => :base, :message => object }
            else
              object.errors.each do |attribute, attribute_error|
                json[:errors] << {
                  :type => 'validation',
                  :field => (options[:rewrite_params] || {}).reverse_merge(attribute => attribute).invert[attribute],
                  :message => brainstem_full_error_message(object, attribute, attribute_error),
                  :index => index
                }
              end
          end
        end
        json
      end

      # Helper to convert an attribute name (e.g., "thing_id") and error (e.g., "is invalid") into a combined full message.
      # Also handles traditional "^You messed up"-style errors that should not be combined with humanized attribute names.
      def brainstem_full_error_message(object, attribute, text)
        text[0] == "^" ? text[1..-1] : object.errors.full_message(attribute, text)
      end
    end
  end
end
