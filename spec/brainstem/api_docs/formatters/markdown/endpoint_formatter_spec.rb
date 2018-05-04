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
              stub(endpoint).custom_response { {} }
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
              let(:const) do
                Class.new do
                  def self.brainstem_model_name
                    :widget
                  end
                end
              end

              before do
                stub(controller).const { const }

                subject.send(:format_params!)
              end

              context "with valid params" do
                let(:root_proc) { Proc.new { "widget" } }
                let(:sprocket_id_proc) { Proc.new { "sprocket_id" } }
                let(:sprocket_child_proc) { Proc.new { "sprocket_child" } }
                let(:default_show_config) {
                  {
                    valid_params: {
                      only: {
                        info: "which ids to include", nodoc: nodoc, type: "array", item_type: "integer"
                      },
                      sprocket_id_proc => {
                        info: "the id of the sprocket", root: root_proc, ancestors: [root_proc], nodoc: nodoc, type: "integer"
                      },
                      sprocket_child_proc => {
                        recursive: true, legacy: false, info: "it does the thing", root: root_proc, ancestors: [root_proc], type: "string"
                      },
                    }
                  }
                }
                let(:show_config) { default_show_config }

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
                      expect(subject.output).to include "- `widget` (`Hash`)\n    - `sprocket_id` (`Integer`) - the id of the sprocket\n    - `sprocket_child` (`String`)"
                    end
                  end

                  context "for params with type array" do
                    it "outputs item type along with the field type" do
                      expect(subject.output).to include "- `only` (`Array<Integer>`) - which ids to include\n"
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
                    let(:show_config) {
                      default_show_config.tap do |config|
                        config[:valid_params][sprocket_id_proc][:required] = required
                      end
                    }

                    context "when required is true" do
                      let(:required) { true }

                      it "includes if required" do
                        expect(subject.output).to include "Required: true"
                      end
                    end

                    context "when required is false" do
                      let(:required) { false }

                      it "includes if required" do
                        expect(subject.output).to_not include "Required"
                      end
                    end
                  end

                  context "with multiple levels of nested params" do
                    let(:sprocket_template_proc) { Proc.new { "sprocket_template" } }
                    let(:sprocket_template_json_proc) { Proc.new { "sprocket_template_json" } }
                    let(:sprocket_template_title_proc) { Proc.new { "sprocket_template_title" } }
                    let(:multi_nested_params) {
                      {
                        sprocket_template_proc => {
                          info: "the template for the sprocket",
                          type: "hash",
                          root: root_proc,
                          ancestors: [root_proc]
                        },
                        sprocket_template_json_proc => {
                          info: "the json blob of the sprocket template",
                          type: "string",
                          ancestors: [root_proc, sprocket_template_proc]
                        },
                        sprocket_template_title_proc => {
                          info: "the title of the sprocket template",
                          type: "string",
                          ancestors: [root_proc, sprocket_template_proc]
                        }
                      }
                    }
                    let(:show_config) {
                      default_show_config.tap do |config|
                        config[:valid_params].merge!(multi_nested_params)
                      end
                    }

                    it "outputs sub params under a list item" do
                      output = subject.output
                      expect(output).to include("##### Valid Parameters\n\n")
                      expect(output).to include("- `only` (`Array<Integer>`) - which ids to include\n")
                      expect(output).to include("- `widget` (`Hash`)\n")
                      expect(output).to include("    - `sprocket_id` (`Integer`) - the id of the sprocket\n")
                      expect(output).to include("    - `sprocket_child` (`String`) - it does the thing\n")
                      expect(output).to include("        - Legacy: false\n")
                      expect(output).to include("        - Recursive: true\n")
                      expect(output).to include("    - `sprocket_template` (`Hash`) - the template for the sprocket\n")
                      expect(output).to include("        - `sprocket_template_json` (`String`) - the json blob of the sprocket template\n")
                      expect(output).to include("        - `sprocket_template_title` (`String`) - the title of the sprocket template\n\n\n")
                    end
                  end
                end
              end

              context "with only default params" do
                let(:default_config) { {
                  valid_params: {
                    Proc.new { "sprocket_name" } => {
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
              context "when has a custom response" do
                before do
                  stub(endpoint).custom_response { true }
                  stub(endpoint).custom_response_configuration_tree { custom_response_configuration }
                end

                context "when the response type is a hash" do
                  let(:custom_response_configuration) do
                    {
                      '_config' => {
                        'type' => 'hash',
                      },
                      'widget_name' => {
                        '_config' => {
                          'type' => 'string',
                          'info' => 'the name of the widget',
                          'nodoc' => false
                        },
                      },
                      'widget_permission' => {
                        '_config' => {
                          'type' => 'hash',
                          'nodoc' => false
                        },
                        'can_edit' => {
                          '_config' => {
                            'type' => 'boolean',
                            'info' => 'can edit the widget',
                            'nodoc' => false
                          },
                        }
                      },
                    }.with_indifferent_access
                  end

                  it "formats the custom response" do
                    subject.send(:format_presents!)

                    output = subject.output
                    expect(output).to include("The resulting JSON is a hash with the following properties\n\n")
                    expect(output).to include("- `widget_name` (`String`) - the name of the widget\n")
                    expect(output).to include("- `widget_permission` (`Hash`)\n")
                    expect(output).to include("    - `can_edit` (`Boolean`) - can edit the widget\n")
                  end
                end

                context "when the response is an array" do
                  let(:custom_response_configuration) do
                    {
                      '_config' => {
                        'type' => 'array',
                        'item_type' => 'hash',
                      },
                      'widget_name' => {
                        '_config' => {
                          'type' => 'string',
                          'info' => 'the name of the widget',
                          'nodoc' => false
                        },
                      },
                      'widget_permissions' => {
                        '_config' => {
                          'type' => 'array',
                          'item_type' => 'hash',
                          'info' => 'the permissions of the widget',
                          'nodoc' => false
                        },
                        'can_edit' => {
                          '_config' => {
                            'type' => 'boolean',
                            'info' => 'can edit the widget',
                            'nodoc' => false
                          },
                        }
                      },
                    }.with_indifferent_access
                  end

                  it "formats the custom response" do
                    subject.send(:format_presents!)

                    output = subject.output
                    expect(output).to include "The resulting JSON is an array of hashes with the following properties\n\n"
                    expect(output).to include("- `widget_name` (`String`) - the name of the widget\n")
                    expect(output).to include("- `widget_permissions` (`Array<Hash>`) - the permissions of the widget\n")
                    expect(output).to include("    - `can_edit` (`Boolean`) - can edit the widget\n")
                  end
                end
              end

              context "when custom response is absent and presenter is present" do
                let(:presenter) { Object.new }

                before do
                  stub(endpoint).custom_response { false }
                  stub(endpoint).presenter_title { "Sprocket Widget" }
                  stub(endpoint).relative_presenter_path_from_controller(:markdown) { "../../sprocket_widget.markdown" }
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
