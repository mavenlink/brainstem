require 'brainstem/api_docs/sinks/abstract_sink'
require 'fileutils'
require 'forwardable'

module Brainstem
  module ApiDocs
    module Sinks
      class ControllerPresenterMultifileSink < AbstractSink
        extend Forwardable

        delegate [:controllers, :presenters] => :atlas


        def <<(atlas)
          self.atlas = atlas

          write_controller_files
          write_presenter_files
        end


        def valid_options
          super | [ :write_method, :format, :write_path ]
        end


        attr_writer     :write_method,
                        :write_path

        attr_accessor   :atlas,
                        :format


        #######################################################################
        private
        #######################################################################

        #
        # Dumps each formatted controller to a file.
        #
        def write_controller_files
          controllers.each_formatted_with_filename(
            format,
            include_actions: true,
            &method(:write_buffer_to_file)
          )
        end


        #
        # Dumps each formatted presenter to a file.
        #
        def write_presenter_files
          presenters.each_formatted_with_filename(format, &method(:write_buffer_to_file))
        end


        #
        # Writes a given bufer to a filename within the base path.
        #
        def write_buffer_to_file(buffer, filename)
          abs_path = File.join(write_path, filename)
          assert_directory_exists!(abs_path)
          write_method.call(abs_path, buffer)
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
