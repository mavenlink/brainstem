require 'brainstem/api_docs'
require 'brainstem/api_docs/sinks/abstract_sink'
require 'fileutils'
require 'forwardable'

module Brainstem
  module ApiDocs
    module Sinks
      class OpenApiSpecificationSink < AbstractSink
        extend Forwardable

        def valid_options
          super | [
            :api_version,
            :write_method,
            :write_path
          ]
        end

        attr_writer :write_method,
                    :write_path

        attr_accessor :api_version,
                      :atlas,
                      :format,
                      :output

        delegate [:controllers, :presenters] => :atlas

        def <<(atlas)
          self.atlas  = atlas
          self.output = ActiveSupport::HashWithIndifferentAccess.new

          # Intro Formatter
          write_info_object!

          # Schema Definitions Formatter

          # Error Definitions Formatter

          # Endpoint Formatter

          # Security Formatter

          write_spec_to_file!
        end


        #######################################################################
        private
        #######################################################################


        DEFAULT_API_VERSION = '1.0.0'
        private_constant :DEFAULT_API_VERSION

        #
        # Returns the version of the API
        #
        def formatted_version
          self.api_version.presence || DEFAULT_API_VERSION
        end

        #
        # Use the metadata formatter to get the swagger & info object
        #
        def write_info_object!
          self.output.merge!(
            ::Brainstem::ApiDocs::FORMATTERS[:info][:oas].call(version: formatted_version)
          )
        end

        #
        # Writes a given bufer to a filename within the base path.
        #
        def write_spec_to_file!(filename = 'specification.yml')
          abs_path = File.join(write_path, filename)
          assert_directory_exists!(abs_path)
          write_method.call(abs_path, output.to_yaml)
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

        def write_path
          @write_path ||= ::Brainstem::ApiDocs.write_path
        end
      end
    end
  end
end
