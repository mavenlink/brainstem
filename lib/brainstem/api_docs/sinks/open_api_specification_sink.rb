require 'brainstem/api_docs'
require 'brainstem/api_docs/formatters/open_api_specification/helper'
require 'brainstem/api_docs/sinks/abstract_sink'
require 'fileutils'
require 'forwardable'

module Brainstem
  module ApiDocs
    module Sinks
      class OpenApiSpecificationSink < AbstractSink
        include Brainstem::ApiDocs::Formatters::OpenApiSpecification::Helper
        extend Forwardable

        def valid_options
          super | [
            :api_version,
            :ignore_tagging,
            :format,
            :write_method,
            :write_path,
            :oas_filename_pattern,
            :output_extension,
            :internal
          ]
        end

        attr_writer :write_method,
                    :write_path

        attr_accessor :api_version,
                      :atlas,
                      :format,
                      :ignore_tagging,
                      :oas_filename_pattern,
                      :output_extension,
                      :output,
                      :internal

        delegate [:controllers, :presenters] => :atlas

        def <<(atlas)
          self.atlas  = atlas
          self.output = ActiveSupport::HashWithIndifferentAccess.new

          write_info_object!
          write_presenter_definitions!
          write_error_definitions!
          write_endpoint_definitions!
          write_tag_definitions!
          write_security_definitions!

          write_spec_to_file!
        end

        #######################################################################
        private
        #######################################################################

        DEFAULT_API_VERSION = '1.0.0'
        private_constant :DEFAULT_API_VERSION

        #
        # Returns the version of the API.
        #
        def formatted_version
          self.api_version.presence || DEFAULT_API_VERSION
        end

        #
        # Use the Info formatter to get the swagger & info object.
        #
        def write_info_object!
          self.output.merge!(
            ::Brainstem::ApiDocs::FORMATTERS[:info][format].call(version: formatted_version)
          )
        end

        #
        # Use the presenter formatters to add schema definitions to the specification.
        #
        def write_presenter_definitions!
          presenter_definitions = presenters
            .formatted(format)
            .inject({}) do |definitions, object_with_definition|

            definitions.merge(object_with_definition)
          end

          inject_objects_under_key!(:definitions, presenter_definitions, true)
        end

        #
        # Add standard error structure to the definitions of the specification.
        #
        def write_error_definitions!
          self.output[:definitions].merge!(
            'Error' => {
              type: 'object',
              properties: {
                type:    type_and_format('string'),
                message: type_and_format('string')
              }
            },
            'Errors' => {
              type: 'object',
              properties: {
                errors: {
                  type: 'array',
                  items: { '$ref' => '#/definitions/Error' }
                }
              }
            }
          )
        end

        #
        # Use the controller formatters to add endpoint definitions to the specification.
        #
        def write_endpoint_definitions!
          controller_definitions = controllers
            .formatted(format)
            .inject({}) do |definitions, path_definition|

            definitions.merge(path_definition)
          end

          inject_objects_under_key!(:paths, controller_definitions, true)
        end

        #
        # Use the controllers names as tag defintions
        #
        def write_tag_definitions!
          self.output.merge!(
            ::Brainstem::ApiDocs::FORMATTERS[:tags][format].call(controllers, ignore_tagging: self.ignore_tagging)
          )
        end

        #
        # Use the Security Definitions formatter to get the security definitions & scopes.
        #
        def write_security_definitions!
          self.output.merge!(
            ::Brainstem::ApiDocs::FORMATTERS[:security][format].call
          )
        end

        #
        # Sort hash by keys and add them to the output nested under the specified top level key
        #
        def inject_objects_under_key!(top_level_key, objects, sort = false)
          self.output[top_level_key] ||= {}

          ordered_keys = sort ? objects.keys.sort : objects.keys
          ordered_keys.each do |object_key|
            self.output[top_level_key][object_key] = objects[object_key]
          end

          self.output
        end

        #
        # Writes a given bufer to a filename within the base path.
        #
        def write_spec_to_file!
          formatted_output = format_output(output, extension)
          abs_path         = File.join(write_path, suggested_filename)

          assert_directory_exists!(abs_path)
          write_method.call(abs_path, formatted_output)
        end

        #
        # Format output to the requested format.
        #
        def format_output(output, requested_format)
          unless %w(json yaml yml).include?(requested_format)
            raise "Open API Specification only supports generation of json / yaml files"
          end

          data = output.to_hash
          requested_format == 'json' ? data.to_json : data.to_yaml
        end

        #
        # Asserts that a directory exists, creating it if it does not.
        #
        def assert_directory_exists!(path)
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)
        end

        #
        # Defines how we write out the files.
        #
        def write_method
          @write_method ||= Proc.new do |name, buff|
            File.write(name, buff, mode: 'w')
          end
        end

        #
        # Defines the output directory for the file.
        #
        def write_path
          @write_path ||= ::Brainstem::ApiDocs.write_path
        end

        #
        # Defines the file extension for the output file.
        #
        def extension
          return output_extension.downcase.to_s if output_extension.present?

          configured_extension = Brainstem::ApiDocs.output_extension.downcase.to_s
          configured_extension == "markdown" ? DEFAULT_OAS_EXTENSION : configured_extension
        end

        DEFAULT_OAS_EXTENSION = 'yml'
        private_constant :DEFAULT_OAS_EXTENSION

        #
        # Defines the name of the file.
        #
        def suggested_filename
          (oas_filename_pattern.presence || DEFAULT_FILENAME_PATTERN)
            .gsub('{{version}}', formatted_version)
            .gsub('{{extension}}', extension)
        end

        DEFAULT_FILENAME_PATTERN = 'specification.{{extension}}'
        private_constant :DEFAULT_FILENAME_PATTERN
      end
    end
  end
end
