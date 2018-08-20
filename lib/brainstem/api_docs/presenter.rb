require 'brainstem/api_docs'
require 'brainstem/concerns/optional'
require 'brainstem/concerns/formattable'
require 'forwardable'
require 'active_support/inflector'

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
          :target_class,
          :filename_pattern,
          :filename_link_pattern,
          :document_empty_associations,
          :document_empty_filters,
          :internal
        ]
      end

      attr_accessor :const,
                    :target_class,
                    :document_empty_associations,
                    :document_empty_filters,
                    :internal

      attr_writer   :filename_pattern,
                    :filename_link_pattern

      alias_method :document_empty_associations?, :document_empty_associations
      alias_method :document_empty_filters?,      :document_empty_filters

      def initialize(atlas, options = {})
        self.atlas = atlas
        self.document_empty_associations = Brainstem::ApiDocs.document_empty_presenter_associations
        self.document_empty_filters      = Brainstem::ApiDocs.document_empty_presenter_filters

        super options
        yield self if block_given?
      end

      def suggested_filename(format)
        filename_pattern
          .gsub('{{name}}', target_class.to_s.underscore)
          .gsub('{{extension}}', extension)
      end

      def suggested_filename_link(format)
        filename_link_pattern
          .gsub('{{name}}', target_class.to_s.underscore)
          .gsub('{{extension}}', extension)
      end

      attr_accessor :atlas

      def extension
        @extension ||= Brainstem::ApiDocs.output_extension
      end

      def filename_pattern
        @filename_pattern ||= Brainstem::ApiDocs.presenter_filename_pattern
      end

      def filename_link_pattern
        @filename_link_pattern ||= Brainstem::ApiDocs.presenter_filename_link_pattern
      end

      delegate :configuration => :const
      delegate :find_by_class => :atlas

      def nodoc?
        nodoc_for?(configuration)
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
        fields.to_h.reject do |_, field|
          invalid_field?(field) || (nested_field?(field) && valid_fields_in(field).none?)
        end
      end
      alias_method :valid_fields_in, :valid_fields

      def invalid_field?(field)
        nodoc_for?(field.options)
      end

      def nested_field?(field)
        field.respond_to?(:configuration)
      end

      def optional_field?(field)
        field.options[:optional]
      end

      def optional_field_names(fields = configuration[:fields], buffer = [])
        fields.to_h.each do |field_name, field_config|
          next if invalid_field?(field_config)

          if optional_field?(field_config)
            buffer << field_name
          elsif nested_field?(field_config)
            optional_field_names_in(field_config.configuration, buffer)
          end
        end

        buffer
      end
      alias_method :optional_field_names_in, :optional_field_names

      def valid_filters
        configuration[:filters]
          .to_h
          .keep_if(&method(:documentable_filter?))
      end

      def documentable_filter?(_, filter)
        !nodoc_for?(filter) &&
          (
            document_empty_filters? || # document empty filters or
            !(filter[:info] || "").empty? # has info string
          )
      end

      def searchable?
        configuration[:search].present?
      end

      def valid_sort_orders
        configuration[:sort_orders].to_h.reject {|_k, v| nodoc_for?(v) }
      end

      def valid_associations
        configuration[:associations]
          .to_h
          .keep_if(&method(:documentable_association?))
      end

      def link_for_association(association)
        if (associated_presenter = find_by_class(association.target_class)) &&
            !associated_presenter.nodoc?
          relative_path_to_presenter(associated_presenter, :markdown)
        else
          nil
        end
      end

      #
      # Returns whether this association should be documented based on nodoc
      # and empty description.
      #
      # @return [Bool] document this association?
      #
      def documentable_association?(_, association)
        !nodoc_for?(association.options) && # not marked nodoc and
          (
            document_empty_associations? || # document empty associations or
            !(association.description.nil? || association.description.empty?) # has description
          )
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
        @default_sort_direction ||= (default_sort_order.split(":")[1] || nil)
      end

      #
      # Returns a key if it exists and is documentable.
      #
      def contextual_documentation(key)
        configuration.has_key?(key) &&
          !nodoc_for?(configuration[key]) &&
          configuration[key][:info]
      end

      #
      # Returns the relative path between this presenter and another given
      # presenter.
      #
      def relative_path_to_presenter(presenter, format)
        my_path        = Pathname.new(File.dirname(suggested_filename_link(format)))
        presenter_path = Pathname.new(presenter.suggested_filename_link(format))

        presenter_path.relative_path_from(my_path).to_s
      end

      private

      def nodoc_for?(config)
        !!(config[:nodoc] || (config[:internal] && !internal))
      end
    end
  end
end
