require 'brainstem/concerns/optional'
require 'brainstem/concerns/formattable'
require 'forwardable'

#
# Wrapper for common presenter information lookups.
#
module Brainstem
  module ApiDocs
    class Presenter
      extend Forwardable
      include Concerns::Optional
      include Concerns::Formattable


      def valid_options
        super | [
          :const,
          :presents,
          :filename_pattern
        ]
      end

      attr_accessor :const,
                    :presents

      attr_writer   :filename_pattern


      def initialize(options = {})
        super options
        yield self if block_given?
      end


      def suggested_filename(format)
        filename_pattern
          .gsub('{{name}}', presents.to_s)
          .gsub('{{extension}}', extension)
      end


      def extension
        @extension ||= Brainstem::ApiDocs.output_extension
      end


      def filename_pattern
        @filename_pattern ||= Brainstem::ApiDocs.presenter_filename_pattern
      end


      delegate :configuration => :const


      def nodoc?
        configuration[:nodoc]
      end


      def title
        contextual_documentation(:title) || const.to_s.demodulize
      end


      def brainstem_keys
        const.possible_brainstem_keys.to_a.sort
      end


      def description
        contextual_documentation(:description) || ""
      end


      def valid_fields(fields = configuration[:fields])
        fields.to_h.reject do |k, v|
          if nested_field?(v)
            valid_fields_in(v).none?
          else
            invalid_field?(v)
          end
        end
      end
      alias_method :valid_fields_in, :valid_fields


      def invalid_field?(field)
        field.options[:nodoc]
      end


      def nested_field?(field)
        !field.respond_to?(:options)
      end


      def valid_filters
        configuration[:filters].to_h.reject {|k, v| v[:nodoc] }
      end


      def valid_sort_orders
        configuration[:sort_orders].to_h.reject {|k, v| v[:nodoc] }
      end


      def valid_associations
        configuration[:associations].to_h.reject {|_, v| v.options[:nodoc] }
      end


      def conditionals
        configuration[:conditionals]
      end


      def default_sort_order
        configuration[:default_sort_order] || ""
      end


      def default_sort_field
        @default_sort_field ||= (default_sort_order.split(":")[0] || nil)
      end


      def default_sort_direction
        @default_sort_field ||= (default_sort_order.split(":")[1] || nil)
      end


      #
      # Returns a key if it exists and is documentable.
      #
      def contextual_documentation(key)
        configuration.has_key?(key) &&
          !configuration[key][:nodoc] &&
          configuration[key][:info]
      end


    end
  end
end
