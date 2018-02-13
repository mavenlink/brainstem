require 'brainstem/api_docs'
require 'brainstem/api_docs/sinks/abstract_sink'
require 'fileutils'
require 'forwardable'

module Brainstem
  module ApiDocs
    module Sinks
      class OpenApiSpecificationSink < AbstractSink
        extend Forwardable

        delegate [:controllers, :presenters] => :atlas

        def <<(atlas)
          self.atlas = atlas
          self.output = {}

          # Intro Formatter
          write_info_object!

          # Schema Definitions Formatter

          # Endpoint Formatter

          # Security Formatter

          # Error Formatter

          write_spec_to_file!
        end


        def valid_options
          super | [ :write_method, :write_path ]
        end


        attr_writer :write_method,
          :write_path

        attr_accessor :atlas,
          :format,
          :output


        #######################################################################
        private
        #######################################################################

        #
        # Use the metadata formatter to get the swagger & info object
        #
        def write_info_object!
          self.output.merge!(
            ::Brainstem::ApiDocs::FORMATTERS[:info][:oas].call(version: "1.0")
          )
        end

        #
        # Writes a given bufer to a filename within the base path.
        #
        def write_spec_to_file!(filename = 'specification_v2.yml')
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