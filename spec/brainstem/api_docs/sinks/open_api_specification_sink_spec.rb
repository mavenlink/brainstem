require 'spec_helper'
require 'brainstem/api_docs/sinks/open_api_specification_sink'
require 'brainstem/api_docs/formatters/open_api_specification/info_formatter'

module Brainstem
  module ApiDocs
    module Sinks
      describe OpenApiSpecificationSink do
        let(:write_method) { Object.new }
        let(:atlas)        { Object.new}
        let(:options)      {
          {
            api_version:  '2.0.0',
            write_method: write_method,
            write_path:   './'
          }
        }

        subject { described_class.new(options) }

        it "calls write info" do
          mock.proxy(subject).write_info_object!
          mock(subject).write_spec_to_file!
          mock.proxy.any_instance_of(Brainstem::ApiDocs::Formatters::OpenApiSpecification::InfoFormatter).call

          subject << atlas
        end

        it "write info properly triggers file write" do
          mock.proxy(subject).write_spec_to_file!
          mock(write_method).call('./specification.yml', anything)

          subject << atlas
        end

        describe "versioning" do
          let(:options) {
            {
              api_version:  api_version,
              write_method: write_method,
              write_path:   './'
            }
          }

          before do
            stub(subject).write_spec_to_file!
          end

          context "when version is specified" do
            let(:api_version) { '2.1.1' }

            it "returns the specified version" do
              expect(subject.send(:formatted_version)).to eq(api_version)
            end
          end

          context "when version is not specified" do
            let(:api_version) { nil }

            it "returns the default version" do
              expect(subject.send(:formatted_version)).to eq('1.0.0')
            end
          end
        end
      end
    end
  end
end
