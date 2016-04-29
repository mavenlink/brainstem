require 'spec_helper'
require 'brainstem/dsl/association'

describe Brainstem::DSL::Association do
  let(:name) { :user }
  let(:target_class) { User }
  let(:description) { "This object's user" }
  let(:options) { { } }
  let(:association) { Brainstem::DSL::Association.new(name, target_class, description, options) }

  describe "#run_on" do
    context 'with no special options' do
      it 'calls the method by name on the model' do
        object = Object.new
        mock(object).user
        association.run_on(object)
      end
    end

    context 'when given a via' do
      let(:options) { { via: :user2 } }

      it 'calls the method named in :via on the model' do
        object = Object.new
        mock(object).user2
        association.run_on(object)
      end
    end

    context 'when given a dynamic lambda' do
      let(:options) { { dynamic: lambda { |model| some_instance_method; :return_value } } }

      it 'calls the lambda in the context of the given instance' do
        instance = Object.new
        mock(instance).some_instance_method
        expect(association.run_on(:anything, instance)).to eq :return_value
      end
    end
  end
end