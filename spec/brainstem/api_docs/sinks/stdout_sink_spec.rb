require 'spec_helper'
require 'brainstem/api_docs/sinks/stdout_sink'

module Brainstem
  module ApiDocs
    module Sinks
      describe StdoutSink do
        let(:output)      { "Zadok the Priest and Nathan the Prophet" }
        let(:dummy_puts)  { Object.new }

        subject { described_class.new(puts_method: dummy_puts) }

        describe "#<<" do
          it "calls the putting method" do
            mock(dummy_puts).call(output)
            subject << output
          end
        end
      end
    end
  end
end
