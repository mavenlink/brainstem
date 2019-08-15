require 'fileutils'
require 'brainstem/concerns/optional'

module Brainstem
  module ApiDocs
    module Sinks
      class AbstractSink
        include Concerns::Optional

        #
        # Primary method for putting the atlas into the sink.
        #
        # @param [Brainstem::ApiDocs::Atlas] the atlas
        #
        def <<(atlas)
          raise NotImplementedError
        end

        #######################################################################$
        private

        def write_path
          @write_path ||= ::Brainstem::ApiDocs.write_path
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
        # Asserts that a directory exists, creating it if it does not.
        #
        def assert_directory_exists!(path)
          dir = File.dirname(path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)
        end

        #
        # Writes a given buffer to a filename within the base path.
        #
        def write_buffer_to_file(buffer, filename)
          abs_path = File.join(write_path, filename)
          assert_directory_exists!(abs_path)
          write_method.call(abs_path, buffer)
        end

        ########################################################################

        #
        # Whitelist of options which can be set on an instance.
        #
        # @return [Array<Symbol>] valid options
        #
        def valid_options
          []
        end
      end
    end
  end
end
