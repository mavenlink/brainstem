require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_collection_formatter'
require 'brainstem/api_docs/endpoint_collection'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        describe EndpointCollectionFormatter do
          let(:atlas)               { Object.new }
          let(:endpoint_collection) { EndpointCollection.new(atlas) }
          let(:nodoc)               { false }

          subject { described_class.new(endpoint_collection) }

          describe "#call" do
            it "formats each endpoint" do
              mock(subject).format_endpoints!
              subject.call
            end
          end


          describe "formatting" do
            describe "#format_endpoints!" do
              let(:endpoint_1) { Object.new }
              let(:endpoint_2) { Object.new }
              let(:endpoint_3) { Object.new }
              let(:endpoint_4) { Object.new }

              before do
                mock(endpoint_collection).only_documentable { [endpoint_1, endpoint_2, endpoint_3, endpoint_4] }

                mock(endpoint_1).formatted_as(:oas_v2) { { "/sprockets" => { "get" => { info: "Get all sprockets" } } } }
                mock(endpoint_2).formatted_as(:oas_v2) { { "/sprockets" => { "post" => { info: "Create a sprocket" } } } }
                mock(endpoint_3).formatted_as(:oas_v2) { { "/sprockets/{id}" => { "patch" => { info: "Update a sprocket" } } } }
                mock(endpoint_4).formatted_as(:oas_v2) { {} }
              end

              it "joins each documentable endpoint" do
                subject.send(:format_endpoints!)
                expect(subject.output).to eq({
                  "/sprockets" => {
                    "get" => { info: "Get all sprockets" },
                    "post" => { info: "Create a sprocket" },
                  },
                  "/sprockets/{id}" => {
                    "patch" => { info: "Update a sprocket" }
                  }
                })
              end
            end
          end
        end
      end
    end
  end
end
