require 'spec_helper'
require 'brainstem/concerns/formattable'

module Brainstem
  module Concerns
    describe Formattable do
      let(:formattable_class) do
        Class.new do
          include Brainstem::Concerns::Formattable
        end
      end

      let(:subject) { formattable_class.new }

      describe "#formatter_type" do
        it "returns the class name underscored and symbolized" do
          stub(formattable_class).to_s { "MyClass" }
          expect(subject.formatter_type).to eq :my_class
        end

        it "returns only the last segment of a class name" do
          stub(formattable_class).to_s { "Namespaced::MyClass" }
          expect(subject.formatter_type).to eq :my_class

        end
      end

    end
  end
end
