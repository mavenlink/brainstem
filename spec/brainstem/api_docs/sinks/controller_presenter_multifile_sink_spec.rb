require 'spec_helper'
require 'brainstem/api_docs/sinks/controller_presenter_multifile_sink'

module Brainstem
  module ApiDocs
    module Sinks
      describe ControllerPresenterMultifileSink do
        let(:write_method)  { Object.new }
        let(:atlas)         { Object.new }
        let(:options) {
          {
            format: :markdown,
            write_method: write_method,
            write_path: './'
          }
        }

        subject { described_class.new(options) }

        context "controllers" do
          before do
            stub(subject).write_presenter_files
          end

          it "writes each controller to its own file" do
            stub(atlas).controllers
              .stub!
              .each_formatted_with_filename(:markdown, include_actions: true)
              .yields('it has info', 'test.markdown')

            mock(write_method).call("./test.markdown", "it has info")
            subject << atlas
          end
        end

        context "presenters" do
          before do
            stub(subject).write_controller_files
          end

          it "writes each presenter to its own file" do
            stub(atlas).presenters
              .stub!
              .each_formatted_with_filename(:markdown)
              .yields('it has info', 'test.markdown')

            mock(write_method).call("./test.markdown", "it has info")
            subject << atlas
          end
        end
      end
    end
  end
end
