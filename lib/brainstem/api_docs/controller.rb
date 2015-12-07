require 'brainstem/concerns/optional'
require 'brainstem/concerns/formattable'
require 'active_support/inflector'
require 'brainstem/api_docs/endpoint_collection'

module Brainstem
  module ApiDocs
    class Controller
      include Concerns::Optional
      include Concerns::Formattable


      def initialize(options = {})
        self.endpoints = EndpointCollection.new
        super options
        yield self if block_given?
      end


      attr_accessor :const,
                    :name,
                    :endpoints,
                    :filename_pattern

      def valid_options
        super | [
          :const,
          :name,
          :formatters,
          :filename_pattern,
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


      def extension
        @extension ||= Brainstem::ApiDocs.output_extension
      end


      def filename_pattern
        @filename_pattern ||= Brainstem::ApiDocs.controller_filename_pattern
      end


      def configuration
        const.configuration
      end


      def default_configuration
        configuration[:_default]
      end


      def nodoc?
        default_configuration[:nodoc]
      end


      def title
        contextual_documentation(:title) || const.to_s.demodulize
      end


      def description
        contextual_documentation(:description) || ""
      end


      #
      # Returns a key if it exists and is documentable.
      #
      def contextual_documentation(key)
        default_configuration.has_key?(key) &&
          !default_configuration[key][:nodoc] &&
          default_configuration[key][:info]
      end

    end
  end
end
