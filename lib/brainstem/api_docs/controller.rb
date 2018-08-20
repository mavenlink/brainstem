require 'brainstem/concerns/optional'
require 'brainstem/concerns/formattable'
require 'active_support/inflector'
require 'brainstem/api_docs/endpoint_collection'
require 'forwardable'

module Brainstem
  module ApiDocs
    class Controller
      extend Forwardable
      include Concerns::Optional
      include Concerns::Formattable

      def initialize(atlas, options = {})
        self.atlas     = atlas
        self.endpoints = EndpointCollection.new(atlas)
        super options
        yield self if block_given?
      end

      attr_accessor :const,
                    :name,
                    :endpoints,
                    :filename_pattern,
                    :atlas,
                    :internal

      attr_writer   :filename_pattern,
                    :filename_link_pattern

      def valid_options
        super | [
          :const,
          :name,
          :formatters,
          :filename_pattern,
          :filename_link_pattern,
          :internal
        ]
      end

      #
      # Adds an existing endpoint to its endpoint collection.
      #
      def add_endpoint(endpoint)
        self.endpoints << endpoint
      end

      def suggested_filename(format)
        filename_pattern
          .gsub('{{namespace}}', const.to_s.deconstantize.underscore)
          .gsub('{{name}}', name.to_s.split("/").last)
          .gsub('{{extension}}', extension)
      end

      def suggested_filename_link(format)
        filename_link_pattern
          .gsub('{{name}}', name.to_s)
          .gsub('{{extension}}', extension)
      end

      def extension
        @extension ||= Brainstem::ApiDocs.output_extension
      end

      def filename_pattern
        @filename_pattern ||= Brainstem::ApiDocs.controller_filename_pattern
      end

      def filename_link_pattern
        @filename_link_pattern ||= Brainstem::ApiDocs.controller_filename_link_pattern
      end

      delegate :configuration => :const
      delegate :find_by_class => :atlas

      def default_configuration
        configuration[:_default]
      end

      def nodoc?
        nodoc_for?(default_configuration)
      end

      def title
        contextual_documentation(:title) || const.to_s.demodulize
      end

      def description
        contextual_documentation(:description) || ""
      end

      def tag
        default_configuration[:tag]
      end

      def tag_groups
        default_configuration[:tag_groups]
      end

      #
      # Returns a key if it exists and is documentable.
      #
      def contextual_documentation(key)
        default_configuration.has_key?(key) &&
          !nodoc_for?(default_configuration[key]) &&
          default_configuration[key][:info]
      end

      def valid_sorted_endpoints
        endpoints.sorted_with_actions_in_controller(const)
      end

      private

      def nodoc_for?(config)
        !!(config[:nodoc] || (config[:internal] && !internal))
      end
    end
  end
end
