require 'spec_helper'
require 'brainstem/api_docs/formatters/markdown/endpoint_formatter'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        describe EndpointFormatter do
          let(:controller)    { Object.new }
          let(:atlas)         { Object.new }
          let(:endpoint)      { Endpoint.new(atlas, {controller: controller }.merge(endpoint_args)) }
          let(:endpoint_args) { {} }
          let(:nodoc)         { false }

          subject { described_class.new(endpoint) }

          describe "#call" do
            before do
              stub(endpoint).nodoc? { nodoc }
            end

            context "when it is nodoc" do
              let(:nodoc) { true }

              before do
                any_instance_of(described_class) do |instance|
                  dont_allow(instance).format_title!
                  dont_allow(instance).format_description!
                  dont_allow(instance).format_endpoint!
                  dont_allow(instance).format_params!
                  dont_allow(instance).format_presents!
                end
              end

              it "returns an empty output" do
                expect(subject.call).to eq ""
              end
            end

            context "when it is not nodoc" do
              it "formats title, description, endpoint, params, and presents" do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_title!
                  mock(instance).format_description!
                  mock(instance).format_endpoint!
                  mock(instance).format_params!
                  mock(instance).format_presents!
                end

                subject.call
              end
            end
          end

          describe "formatting" do
            let(:lorem)           { "lorem ipsum dolor sit amet" }
            let(:default_config)  { {} }
            let(:show_config)     { {} }

            let(:configuration)   { {
              :_default => default_config,
              :show => show_config,
            } }

            let(:endpoint_args) { { action: :show } }

            before do
              stub(controller).configuration { configuration }
            end

            describe "#format_title!" do
              it "prints it as an h4" do
                stub(endpoint).title { lorem }
                mock(subject).md_h4(lorem) { lorem }
                subject.send(:format_title!)
                expect(subject.output).to eq lorem
              end
            end


            describe "#format_description!" do
              context "when present" do
                before do
                  stub(endpoint).description { lorem }
                end

                it "prints it as a p" do
                  mock(subject).md_p(lorem) { lorem }
                  subject.send(:format_description!)
                  expect(subject.output).to eq lorem
                end
              end

              context "when absent" do
                before do
                  stub(endpoint).description { "" }
                end

                it "prints nothing" do
                  dont_allow(subject).md_p
                  subject.send(:format_description!)
                  expect(subject.output).to eq ""
                end

              end
            end


            describe "#format_endpoint!" do
              let(:endpoint_args) { { http_methods: %w(get post), path: "/widgets(.:format)" } }

              it "formats it as code, subbing the appropriate format" do
                mock(subject).md_code("GET / POST /widgets.json") { lorem }
                subject.send(:format_endpoint!)
                expect(subject.output).to eq lorem
              end

              it "includes the joined HTTP methods" do
                subject.send(:format_endpoint!)
                expect(subject.output).to include "GET / POST"
              end

              it "includes the path" do
                subject.send(:format_endpoint!)
                expect(subject.output).to include "/widgets"
              end
            end


            describe "#format_params!" do
              before do
                subject.send(:format_params!)
              end


              context "with valid params" do
                let(:show_config) { {
                  valid_params: {
                    only: { info: "which ids to include", nodoc: nodoc, type: "array", item_type: "integer" },
                    sprocket_id: { info: "the id of the sprocket", root: "widget", nodoc: nodoc, type: "integer" },
                    sprocket_child: { recursive: true, legacy: false, info: "it does the thing", root: "widget", type: "string" },
                  }
                } }

                context "when nodoc" do
                  let(:nodoc) { true }

                  it "removes them from the list" do
                    expect(subject.output).to include "`widget`"
                    expect(subject.output).to include "`sprocket_child`"
                    expect(subject.output).not_to include "`sprocket_id`"
                    expect(subject.output).not_to include "`only`"
                  end
                end

                context "when not nodoc" do
                  it "outputs a header" do
                    expect(subject.output).to include "Valid Parameters"
                  end

                  it "spits each root item out as a list item" do
                    expect(subject.output.scan(/\n-/).count).to eq 2
                  end

                  it "makes the key an inline code block" do
                    expect(subject.output).to include "`sprocket_id`"
                  end

                  context "for non-root params" do
                    it "outputs sub params under a list item" do
                      expect(subject.output).to include "- `widget`\n    - `sprocket_id` (`Integer`) - the id of the sprocket\n    - `sprocket_child` (`String`)"
                    end
                  end

                  it "includes the info on a hash key" do
                    expect(subject.output).to include "`sprocket_child` (`String`) - it does the thing"
                  end

                  it "includes the recursivity if specified" do
                    expect(subject.output).to include "Recursive: true"
                  end

                  it "includes the legacy status if specified" do
                    expect(subject.output).to include "Legacy: false"
                  end

                  context "when required option is specified" do
                    context "when required is true" do
                      let(:show_config) { {
                        valid_params: {
                          only: { info: "which ids to include", nodoc: nodoc },
                          sprocket_id: { info: "the id of the sprocket", root: "widget", nodoc: nodoc, required: true },
                          sprocket_child: { recursive: true, legacy: false, info: "it does the thing", root: "widget" },
                        }
                      } }

                      it "includes if required" do
                        expect(subject.output).to include "Required: true"
                      end
                    end

                    context "when required is false" do
                      let(:show_config) { {
                        valid_params: {
                          only: { info: "which ids to include", nodoc: nodoc },
                          sprocket_id: { info: "the id of the sprocket", root: "widget", nodoc: nodoc, required: false },
                          sprocket_child: { recursive: true, legacy: false, info: "it does the thing", root: "widget" },
                        }
                      } }

                      it "includes if required" do
                        expect(subject.output).to_not include "Required"
                      end
                    end
                  end
                end
              end


              context "with only default params" do
                let(:default_config) { {
                  valid_params: {
                    sprocket_name: {
                      info: "the name of the sprocket",
                      nodoc: nodoc
                    }
                  }
                } }

                context "when nodoc" do
                  let(:nodoc) { true }

                  it "shows no parameters" do
                    expect(subject.output).to eq ""
                  end
                end

                context "when not nodoc" do
                  it "falls back to the default" do
                    expect(subject.output).to include "`sprocket_name` - the name of the sprocket"
                  end
                end
              end


              context "with no valid params" do
                it "outputs nothing" do
                  expect(subject.output).to eq ""
                end
              end

            end


            describe "#format_presents!" do
              let(:presenter) { Object.new }

              before do
                stub(endpoint).presenter_title { "Sprocket Widget" }
                stub(endpoint).relative_presenter_path_from_controller(:markdown) { "../../sprocket_widget.markdown" }
              end

              context "when present" do
                before do
                  stub(endpoint).presenter { presenter }
                end

                it "outputs a header" do
                  subject.send(:format_presents!)
                  expect(subject.output).to include "Data Model"
                end

                it "displays a link" do
                  subject.send(:format_presents!)
                  expect(subject.output).to include "[Sprocket Widget](../../sprocket_widget.markdown)"
                end
              end

              context "when not present" do
                it "does not output anything" do
                  subject.send(:format_presents!)
                  expect(subject.output).not_to include "Data Model"
                end
              end
            end
          end
        end
      end
    end
  end
end
