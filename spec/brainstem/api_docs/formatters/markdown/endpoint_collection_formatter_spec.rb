require 'spec_helper'
require 'brainstem/api_docs/formatters/markdown/endpoint_collection_formatter'
require 'brainstem/api_docs/endpoint_collection'

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        describe EndpointCollectionFormatter do
          let(:atlas)               { Object.new }
          let(:endpoint_collection) { EndpointCollection.new(atlas) }
          let(:nodoc)               { false }

          subject { described_class.new(endpoint_collection) }

          describe "#call" do
            it "formats each endpoint" do
              mock(subject).format_endpoints!
              stub(subject).format_zero_text!
              subject.call
            end

            context "when has content" do
              before do
                stub(subject).output { "not empty" }
              end

              it "does not format zero text" do
                dont_allow(subject).format_zero_text!
                subject.call
              end
            end

            context "when no content" do
              it "formats zero text" do
                stub(subject).format_endpoints!
                mock(subject).format_zero_text!
                subject.call
              end
            end
          end


          describe "formatting" do
            describe "#format_endpoints!" do
              it "joins each documentable endpoint" do
                mock(subject).all_formatted_endpoints { ["thing 1", "thing 2"] }
                subject.send(:format_endpoints!)
                expect(subject.output).to eq "thing 1-----\n\nthing 2"
              end
            end


            describe "#format_zero_text!" do
              it "appends the zero text" do
                subject.send(:format_zero_text!)
                expect(subject.output).to eq "No endpoints were found."
              end
            end
          end


          describe "#all_formatted_endpoints" do
            it "retrieves all formatted endpoints" do
              documentable_collection = Object.new
              mock(documentable_collection).formatted(:markdown) { [] }
              stub(endpoint_collection).only_documentable { documentable_collection }
              subject.send(:all_formatted_endpoints)
            end

            it "rejects blank endpoints" do
              stub(endpoint_collection).only_documentable
                .stub!.formatted(:markdown) { [ "thing 1", "", "thing 3" ] }

              expect(subject.send(:all_formatted_endpoints)).to \
                eq [ "thing 1", "thing 3" ]
            end
          end
        end


      end
    end
  end
end
