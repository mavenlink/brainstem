require 'spec_helper'
require 'brainstem/api_docs/sinks/puml_sink'

module Brainstem
  module ApiDocs
    module Sinks
      describe PumlSink do
        mock_writer_class = Class.new do
          def call(buffer, file)
            @written = buffer
            @file = file
          end

          attr_reader :written, :file
        end

        mock_presenter_collection = Class.new do
          def formatted(format)
            raise 'unexpected format' unless format == :puml
            ["formatted", "presenters"]
          end

          attr_reader :format, :method
        end

        let(:mock_presenters) { mock_presenter_collection.new }
        let(:mock_writer) { mock_writer_class.new }
        let(:atlas) { OpenStruct.new(presenters: mock_presenters) }
        subject { described_class.new(writer: mock_writer) }

        it "writes the header" do
          subject << atlas
          expect(mock_writer.written).to include("@startuml")
        end

        it "writes the footer" do
          subject << atlas
          expect(mock_writer.written).to include("@enduml")
        end
        
        it "writes out to a puml spec file" do
          subject << atlas
          expect(mock_writer.file).to eq("specification.puml")
        end

        it "writes out all the presenters in the correct format" do
          subject << atlas
          expect(mock_writer.written).to include("formatted\npresenters")
        end
      end
    end
  end
end 
