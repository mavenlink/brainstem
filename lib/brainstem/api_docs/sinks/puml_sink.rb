require 'brainstem/api_docs/sinks/abstract_sink'

module Brainstem
  module ApiDocs
    module Sinks
      class PumlSink < AbstractSink
        def self.call(*args)
          new(*args)
        end

        def <<(atlas)
          write_complete_specification!(atlas)
          write_individual_class_specifications!(atlas)
        end

        #######################################################################
        private
        #######################################################################

        def format_puml_schema(&block)
          buffer = StringIO.new

          buffer.puts("@startuml")
          yield(buffer)
          buffer.puts("@enduml")

          buffer.string
        end

        #
        # Dump complete specification to a single file.
        #
        def write_complete_specification!(atlas)
          output = format_puml_schema do |buffer|
            atlas.presenters.each do |presenter|
              next if presenter.nodoc?

              buffer.puts(presenter.formatted_as(:puml))
            end
          end

          write_buffer_to_file(output, "mavenlink_api_v1_specification.puml")
        end

        #
        # Dumps each formatted presenter to a file.
        #
        def write_individual_class_specifications!(atlas)
          atlas.presenters.each do |presenter|
            next if presenter.nodoc?

            output = format_puml_schema do |buffer|
              format_options = { add_association_class_definitions: true }

              buffer.puts(presenter.formatted_as(:puml, format_options))
            end

            write_buffer_to_file(output, individual_class_file_path(presenter))
          end
        end

        def individual_class_file_path(associated_presenter)
          File.join("classes", "{{name}}.{{extension}}")
            .gsub('{{name}}', individual_class_filename(associated_presenter))
            .gsub('{{extension}}', "puml")
        end

        def individual_class_filename(associated_presenter)
          [
            'mavenlink_api_v1',
            associated_presenter.target_class
                .to_s
                .underscore
                .gsub('/', '_')
          ].join('_')
        end
      end
    end
  end
end
