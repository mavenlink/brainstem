require 'brainstem/api_docs/sinks/abstract_sink'

module Brainstem
  module ApiDocs
    module Sinks
      class PumlSink < AbstractSink
        def self.call(*args)
          new(*args).call
        end

        def call
          buffer = StringIO.new
          buffer.puts("@startuml")
          buffer.puts("@enduml")
          write_buffer_to_file(buffer.string, 'specification.puml')
        end
      end
    end
  end
end
