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
            write_method: write_method,
            write_path: './'
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
      end
    end
  end
end
