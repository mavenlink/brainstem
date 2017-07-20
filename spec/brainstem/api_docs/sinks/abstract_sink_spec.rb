require 'spec_helper'
require 'brainstem/api_docs/sinks/abstract_sink'

module Brainstem
  module ApiDocs
    module Sinks
      describe AbstractSink do
        describe "#<<" do
          it "is not implemented" do
            expect { subject << Object.new }.to raise_error NotImplementedError
          end
        end
      end
    end
  end
end
