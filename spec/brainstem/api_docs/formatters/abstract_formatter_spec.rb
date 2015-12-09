require 'spec_helper'
require 'brainstem/api_docs/formatters/abstract_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      describe AbstractFormatter do
        subject { AbstractFormatter.new }

        describe ".call" do
          it "instantiates a new instance and calls it, passing the instance all args" do
            mock(described_class).new(1, 2, {}) do |instance|
              mock(Object.new).call
            end

            described_class.call(1, 2, {})
          end
        end


        describe "#call" do
          it "is not implemented" do
            expect { subject.call }.to raise_error NotImplementedError
          end
        end

      end
    end
  end
end
