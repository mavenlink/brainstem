require "spec_helper"
require "brainstem/api_docs/formatters/open_api_specification/version_2/endpoint_formatter"
require "brainstem/api_docs/endpoint"

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          describe EndpointFormatter do
            let(:controller)    { Object.new }
            let(:presenter)     { Object.new }
            let(:atlas)         { Object.new }
            let(:endpoint)      {
              ::Brainstem::ApiDocs::Endpoint.new(
                atlas,
                {
                  controller:   controller,
                  http_methods: %w(get post),
                  path:         "/v2/widgets(.:format)"
                }.merge(endpoint_args)
              )
            }
            let(:endpoint_args)   { {} }
            let(:nodoc)           { false }
            let(:controller_tag)  { nil }
            let(:security)        { nil }

            subject { described_class.new(endpoint) }

            before do
              stub(endpoint).presenter { presenter }
              stub(endpoint).security { security }
              stub(controller).tag { controller_tag }
            end

            describe "#call" do
              before do
                stub(endpoint).nodoc? { nodoc }
              end

              context "when endpoint has no presenter associated with it" do
                let(:nodoc) { true }
                let(:presenter) { nil }

                before do
                  any_instance_of(described_class) do |instance|
                    dont_allow(instance).format_summary!
                    dont_allow(instance).format_optional_info!
                    dont_allow(instance).format_security!
                    dont_allow(instance).format_parameters!
                    dont_allow(instance).format_response!
                    dont_allow(instance).format_tags!
                  end
                end

                it "returns an empty output" do
                  expect(subject.call).to eq({})
                end
              end

              context "when it is nodoc" do
                let(:nodoc) { true }

                before do
                  any_instance_of(described_class) do |instance|
                    dont_allow(instance).format_summary!
                    dont_allow(instance).format_optional_info!
                    dont_allow(instance).format_security!
                    dont_allow(instance).format_parameters!
                    dont_allow(instance).format_response!
                    dont_allow(instance).format_tags!
                  end
                end

                it "returns an empty output" do
                  expect(subject.call).to eq({})
                end
              end

              context "when it is not nodoc" do
                before do
                  stub(controller).tag { "CRUD: Widgets" }
                  stub(endpoint).security { "CRUD: Widgets" }
                end

                it "formats endpoint properties" do
                  any_instance_of(described_class) do |instance|
                    mock(instance).format_summary!
                    mock(instance).format_optional_info!
                    mock(instance).format_security!
                    mock(instance).format_parameters!
                    mock(instance).format_response!
                    mock(instance).format_tags!
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

              describe "#formatted_url" do
                let(:endpoint_args) { { path: "/widgets(.:format)" } }

                it "returns the url without the format" do
                  expect(subject.send(:formatted_url)).to eq("/widgets")
                end

                context "when :id is present in the url" do
                  let(:endpoint_args) { { path: "/widgets/:id(.:format)" } }

                  it "replace the :id param with {id}" do
                    expect(subject.send(:formatted_url)).to eq("/widgets/{id}")
                  end
                end

                context "when :some_id is present in the url" do
                  let(:endpoint_args) { { path: "/widgets/:some_id/blah/:id(.:format)" } }

                  it "replace the :some_id param with {some_id}" do
                    expect(subject.send(:formatted_url)).to eq("/widgets/{some_id}/blah/{id}")
                  end
                end
              end

              describe "#format_summary!" do
                it "sets the title in the output" do
                  stub(endpoint).title { lorem }
                  subject.send(:format_summary!)
                  expect(subject.output["/widgets"]["get"]["summary"]).to eq(lorem)
                end
              end

              describe "#format_tags!" do
                let(:controller_name) { "awesome_sauce" }

                before do
                  stub(controller).name { controller_name }
                end

                context "when controller is not assigned a tag" do
                  before do
                    stub(controller).tag { nil }
                  end

                  it "sets the title in the output" do
                    subject.send(:format_tags!)
                    expect(subject.output["/widgets"]["get"]["tags"]).to eq(["Awesome Sauce"])
                  end
                end

                context "when controller is assigned a tag" do
                  before do
                    stub(controller).tag { "Breaking Bad" }
                  end

                  it "sets the assigned tag name in the output" do
                    subject.send(:format_tags!)
                    expect(subject.output["/widgets"]["get"]["tags"]).to eq(["Breaking Bad"])
                  end
                end
              end

              describe "#format_optional_info!" do
                context "when present" do
                  let(:description)   { " lorem ipsum dolor sit amet " }
                  let(:operation_id)  { "Operation 1" }
                  let(:consumes)      { %w(application/json) }
                  let(:produces)      { %w(application/json) }
                  let(:schemes)       { %w(http https) }
                  let(:external_docs) { { url: "/", description: "Blah" } }
                  let(:deprecated)    { true }

                  before do
                    stub(endpoint).description    { lorem }
                    stub(endpoint).operation_id   { operation_id }
                    stub(endpoint).consumes       { consumes }
                    stub(endpoint).produces       { produces }
                    stub(endpoint).schemes        { schemes }
                    stub(endpoint).external_docs  { external_docs }
                    stub(endpoint).deprecated     { deprecated }
                  end

                  it "includes the description key with the given description" do
                    subject.send(:format_optional_info!)

                    output = subject.output["/widgets"]["get"]
                    expect(output["description"]).to eq("Lorem ipsum dolor sit amet.")
                    expect(output["operation_id"]).to eq(operation_id)
                    expect(output["consumes"]).to eq(consumes)
                    expect(output["produces"]).to eq(produces)
                    expect(output["schemes"]).to eq(schemes)
                    expect(output["external_docs"]).to eq(external_docs.with_indifferent_access)
                    expect(output["deprecated"]).to eq(deprecated)
                  end
                end

                context "when absent" do
                  before do
                    stub(endpoint).description    { nil }
                    stub(endpoint).operation_id   { nil }
                    stub(endpoint).consumes       { nil }
                    stub(endpoint).produces       { nil }
                    stub(endpoint).schemes        { nil }
                    stub(endpoint).external_docs  { nil }
                    stub(endpoint).deprecated     { nil }
                  end

                  it "does not include the description key" do
                    subject.send(:format_optional_info!)

                    output = subject.output["/widgets"]["get"].keys
                    expect(output).to_not include(
                      "description",
                      "operation_id",
                      "consumes",
                      "produces",
                      "schemes",
                      "external_docs",
                      "deprecated"
                    )
                  end
                end
              end

              describe "#format_security!" do
                before do
                  stub(endpoint).security { security }
                end

                context "when specified" do
                  let(:security) { { petstore_auth: ["write:pets", "read:pets"] } }

                  it "sets the security property in the output" do
                    subject.send(:format_security!)

                    expect(subject.output["/widgets"]["get"]["security"]).to eq(security.with_indifferent_access)
                  end
                end

                # NOTE: Empty Array removes all security restrictions on the endpoint.
                context "when empty array is specified" do
                  let(:security) { [] }

                  it "sets the security property as an emtpy array" do
                    subject.send(:format_security!)

                    expect(subject.output["/widgets"]["get"]["security"]).to eq([])
                  end
                end

                context "when nothing is specified" do
                  let(:security) { nil }

                  it "does not add the security property" do
                    subject.send(:format_security!)

                    expect(subject.output["/widgets"]["get"]).to_not have_key("security")
                  end
                end
              end

              describe "#format_parameters!" do
                let(:formatted_params) { { "params_for_endpoint" => true } }

                it "calls EndpointParamsFormatter" do
                  mock(Brainstem::ApiDocs::FORMATTERS[:parameters][:oas_v2])
                    .call(endpoint) { formatted_params }
                  subject.send(:format_parameters!)

                  expect(subject.output["/widgets"]["get"]["parameters"]).to eq(formatted_params)
                end
              end

              describe "#format_response!" do
                let(:formatted_response) { { "response_for_endpoint" => true } }

                it "calls EndpointResponseFormatter" do
                  mock(Brainstem::ApiDocs::FORMATTERS[:response][:oas_v2])
                    .call(endpoint) { formatted_response }
                  subject.send(:format_response!)

                  expect(subject.output["/widgets"]["get"]["responses"]).to eq(formatted_response)
                end
              end
            end
          end
        end
      end
    end
  end
end
