require 'spec_helper'
require 'brainstem/api_docs/formatters/markdown/controller_formatter'
require 'brainstem/api_docs/controller'

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        describe ControllerFormatter do
          let(:const)      { Object.new }
          let(:atlas)      { Object.new }
          let(:controller) { Controller.new(atlas, const: const) }
          let(:configuration) { {} }

          let(:endpoint_1) { Object.new }
          let(:endpoints)  { [ endpoint_1 ] }
          let(:nodoc)      { false }
          let(:options)    { {} }

          subject { described_class.new(controller, options) }

          before do
            stub(const).configuration { configuration }
          end

          describe "#call" do
            let(:configuration) { { _default: { nodoc: nodoc } } }

            context "when nodoc specified" do
              let(:nodoc) { true }

              before do
                dont_allow(subject).format_title!
                dont_allow(subject).format_description!
                dont_allow(subject).format_actions!
              end

              it "returns a blank output" do
                expect(subject.call).to eq ""
              end
            end

            context "when nodoc not specified" do
              it "formats title, description, actions, and presenters" do
                mock(subject).format_title!
                mock(subject).format_description!
                mock(subject).format_actions!

                subject.call
              end
            end
          end

          describe "formatting" do
            let(:lorem)          { "lorem ipsum dolor sit amet" }
            let(:default_config) { {} }
            let(:configuration)  { { _default: default_config } }

            describe "#format_title!" do
              it "outputs it as an h2" do
                stub(controller).title { lorem }
                mock(subject).md_h2(lorem) { lorem }
                subject.send(:format_title!)
                expect(subject.output).to eq lorem
              end
            end

            describe "#format_description!" do
              context "when present" do
                before do
                  stub(controller).description { lorem }
                end

                it "prints it as a p" do
                  mock(subject).md_p(lorem) { lorem }
                  subject.send(:format_description!)
                  expect(subject.output).to eq lorem
                end
              end

              context "when absent" do
                before do
                  stub(controller).description { "" }
                end

                it "prints nothing" do
                  dont_allow(subject).md_p
                  subject.send(:format_description!)
                  expect(subject.output).to eq ""
                end

              end
            end

            describe "#format_actions!" do
              context "if include actions" do
                let(:options) { { include_actions: true } }

                it "creates a subheading" do
                  stub(controller).valid_sorted_endpoints.stub!.formatted_as(:markdown, anything) { "" }
                  subject.send(:format_actions!)
                  expect(subject.output).to include "### Endpoints"
                end

                it "appends the formatted output of the endpoints" do
                  stub(controller).valid_sorted_endpoints.stub!.formatted_as(:markdown, anything) { "collection" }
                  subject.send(:format_actions!)
                  expect(subject.output).to include "collection"
                end
              end

              context "if not include actions" do
                it "shows nothing" do
                  subject.send(:format_actions!)
                  expect(subject.output).to eq ""
                end
              end
            end
          end

        end
      end
    end
  end
end
