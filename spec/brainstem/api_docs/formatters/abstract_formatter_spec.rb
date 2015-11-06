require 'spec_helper'
require 'brainstem/api_docs/formatters/abstract_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      describe AbstractFormatter do
        subject { AbstractFormatter.new }

        describe ".call" do
          before do
            any_instance_of(described_class) do |instance|
              mock.proxy(instance).initialize(1, 2, {})
              mock(instance).call
            end
          end

          it "instantiates a new instance and calls it, passing the instance all args" do
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
