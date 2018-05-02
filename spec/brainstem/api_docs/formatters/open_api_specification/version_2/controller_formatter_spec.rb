require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/controller_formatter'
require 'brainstem/api_docs/controller'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
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
                  dont_allow(subject).format_actions!
                end

                it "returns an empty hash" do
                  expect(subject.call).to eq({})
                end
              end

              context "when nodoc not specified" do
                it "formats actions" do
                  mock(subject).format_actions!

                  subject.call
                end
              end
            end

            describe "formatting" do
              let(:lorem)          { "lorem ipsum dolor sit amet" }
              let(:default_config) { {} }
              let(:configuration)  { { _default: default_config } }

              describe "#format_actions!" do
                context "if include actions" do
                  let(:options) { { include_actions: true } }

                  it "calls formatted_as with :oas_v2 on the sorted endpoints in the controller" do
                    stub(controller).valid_sorted_endpoints.stub!.formatted_as(:oas_v2) { { index: true } }
                    subject.send(:format_actions!)
                  end
                end

                context "if not include actions" do
                  let(:options) { { include_actions: false } }

                  it "shows nothing" do
                    subject.send(:format_actions!)
                    expect(subject.output).to eq({})
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
