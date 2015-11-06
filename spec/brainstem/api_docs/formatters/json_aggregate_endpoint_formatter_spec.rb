require 'spec_helper'
require 'brainstem/api_docs/formatters/json_aggregate_endpoint_formatter'
require 'ostruct'

#
# This is the simplest example of a formatter. In particular, it is an example
# of an aggregate formatter, which turns a collection of unformatted endpoints
# (+Endpoint+ objects) into concatenated JSON output.
#
# In other more complex situations, you might have a +JsonEndpointFormatter+, which
# would format a single Endpoint, as well as a
# +JsonEndpointCollectionFormatter+, which would format a series of pre-formatted
# endpoints, likely concatenating them.
#
# This is provided largely as an example, and is likely of limited value
# otherwise.
#
module Brainstem
  module ApiDocs
    module Formatters
      describe JsonAggregateEndpointFormatter do
        let(:atlas)       { Object.new }
        let(:options)     { {} }
        let(:endpoint_1)  { OpenStruct.new(path: '/blah') }

        subject { JsonAggregateEndpointFormatter.new(options) }

        before do
          stub(atlas) do |a|
            a.endpoints { [ endpoint_1 ] }
          end
        end


        describe "#call" do
          context "when the pretty option is not true" do
            it "formats each endpoint as JSON" do
              expect(subject.call(atlas)).to eq %Q([{"path":"/blah"}])
            end
          end

          context "when the pretty option is true" do
            let(:options) { { pretty: true } }
            it "pretty generates if the pretty option is true" do
              expected_output = <<-EOS
[
  {
    "path": "/blah"
  }
]
              EOS

              expect(subject.call(atlas)).to eq expected_output.chomp
            end
          end
        end
      end
    end
  end
end
