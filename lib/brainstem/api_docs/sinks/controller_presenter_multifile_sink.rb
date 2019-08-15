require 'brainstem/api_docs/sinks/abstract_sink'
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
          super | [ :format ]
        end

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
      end
    end
  end
end
