require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_formatter'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        describe EndpointFormatter do
          let(:controller)    { Object.new }
          let(:presenter)     { Object.new }
          let(:atlas)         { Object.new }
          let(:endpoint)      {
            Endpoint.new(
              atlas,
              {
                controller:   controller,
                http_methods: %w(get post),
                path:         '/widgets(.:format)'
              }.merge(endpoint_args)
            )
          }
          let(:endpoint_args) { {} }
          let(:nodoc)         { false }

          subject { described_class.new(endpoint) }

          before do
            stub(endpoint).presenter { presenter }
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
                  dont_allow(instance).format_description!
                  dont_allow(instance).format_parameters!
                  dont_allow(instance).format_response!
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
                  dont_allow(instance).format_description!
                  dont_allow(instance).format_parameters!
                  dont_allow(instance).format_response!
                end
              end

              it "returns an empty output" do
                expect(subject.call).to eq({})
              end
            end

            context "when it is not nodoc" do
              it "formats title, description, endpoint, params, and presents" do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_summary!
                  mock(instance).format_description!
                  mock(instance).format_parameters!
                  mock(instance).format_response!
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
              let(:endpoint_args) { { path: '/widgets(.:format)' } }

              it "returns the url without the format" do
                expect(subject.send(:formatted_url)).to eq('/widgets')
              end

              context "when :id is present in the url" do
                let(:endpoint_args) { { path: '/widgets/:id(.:format)' } }

                it "replace the :id param with {id}" do
                  expect(subject.send(:formatted_url)).to eq('/widgets/{id}')
                end
              end

              context "when :some_id is present in the url" do
                let(:endpoint_args) { { path: '/widgets/:some_id/blah/:id(.:format)' } }

                it "replace the :some_id param with {some_id}" do
                  expect(subject.send(:formatted_url)).to eq('/widgets/{some_id}/blah/{id}')
                end
              end
            end

            describe "#format_summary!" do
              it "sets the title in the output" do
                stub(endpoint).title { lorem }
                subject.send(:format_summary!)
                expect(subject.output['/widgets']['get']['summary']).to eq(lorem)
              end
            end

            describe "#format_description!" do
              let(:valid_associations) { {} }

              before do
                stub(presenter).valid_associations { valid_associations }
              end

              context "when present" do
                before do
                  stub(endpoint).description { lorem }
                end

                context "when an endpoint has valid associations" do
                  let(:valid_associations) {
                    {
                      'association_1' => OpenStruct.new(
                        name:         'association_1',
                        target_class: 'association_1_class',
                        description:  'association_1 description'
                      ),
                      'association_2' => OpenStruct.new(
                        name:         'association_2',
                        target_class: 'association_2_class',
                        description:  'association_2 description'
                      )
                    }
                  }

                  it "adds them to the description" do
                    subject.send(:format_description!)

                    result = subject.output['/widgets']['get']['description']
                    expect(result).to include("#{lorem}.")
                    expect(result).to include('Associations')
                    expect(result).to include("Association Name | Associated Class | Description\n")
                    expect(result).to include("`association_1` | association_1_class | association_1 description\n")
                    expect(result).to include("`association_2` | association_2_class | association_2 description\n")
                  end
                end

                context "when an endpoint does not have valid associations" do
                  let(:valid_associations) { {} }

                  it "only includes the endpoint description" do
                    subject.send(:format_description!)
                    expect(subject.output['/widgets']['get']['description']).to eq("#{lorem}.")
                  end
                end
              end

              context "when absent" do
                before do
                  stub(endpoint).description { "" }
                end

                context "when an endpoint has valid associations" do
                  let(:valid_associations) {
                    {
                      'association_1' => OpenStruct.new(
                        name:         'association_1',
                        target_class: 'association_1_class',
                        description:  'association_1 description'
                      ),
                      'association_2' => OpenStruct.new(
                        name:         'association_2',
                        target_class: 'association_2_class',
                        description:  'association_2 description'
                      )
                    }
                  }

                  it "adds them to the description" do
                    subject.send(:format_description!)

                    result = subject.output['/widgets']['get']['description']
                    expect(result).to include('Associations')
                    expect(result).to include("Association Name | Associated Class | Description\n")
                    expect(result).to include("`association_1` | association_1_class | association_1 description\n")
                    expect(result).to include("`association_2` | association_2_class | association_2 description\n")
                  end
                end

                context "when an endpoint does not have valid associations" do
                  let(:valid_associations) { {} }

                  it "prints nothing" do
                    subject.send(:format_description!)
                    expect(subject.output['/widgets']['get']).to_not have_key('description')
                  end
                end
              end
            end

            describe "#format_parameters!" do
              let(:formatted_params) { { 'params_for_endpoint' => true } }

              it "calls EndpointParamsFormatter" do
                mock(Brainstem::ApiDocs::Formatters::OpenApiSpecification::EndpointParamsFormatter)
                  .call(endpoint) { formatted_params }
                subject.send(:format_parameters!)

                expect(subject.output['/widgets']['get']['parameters']).to eq(formatted_params)
              end
            end

            describe "#format_response!" do
              let(:formatted_response) { { 'response_for_endpoint' => true } }

              it "calls EndpointParamsFormatter" do
                mock(Brainstem::ApiDocs::Formatters::OpenApiSpecification::EndpointResponseFormatter)
                  .call(endpoint) { formatted_response }
                subject.send(:format_response!)

                expect(subject.output['/widgets']['get']['responses']).to eq(formatted_response)
              end
            end
          end
        end
      end
    end
  end
end
