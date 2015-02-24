require 'spec_helper'
require 'brainstem/dsl/association'

describe Brainstem::DSL::Association do
  let(:name) { :user }
  let(:target_class) { User }
  let(:description) { "This object's user" }
  let(:options) { { } }
  let(:association) { Brainstem::DSL::Association.new(name, target_class, description, options) }

  describe '#brainstem_key' do
    describe 'when the :brainstem_key is in the options' do
      let(:options) { { brainstem_key: 'my_users' } }

      it 'returns it' do
        expect(association.brainstem_key).to eq 'my_users'
      end
    end

    describe 'when a target class is present' do
      class AwesomeUser < ActiveRecord::Base
      end

      let(:target_class) { AwesomeUser }

      it 'returns it underscored and pluralized' do
        expect(association.brainstem_key).to eq 'awesome_users'
      end
    end

    describe 'when a STI class is present' do
      class AwesomerUser < User
      end

      let(:target_class) { AwesomerUser }

      describe 'by default' do
        it 'returns the subclass name underscored and pluralized' do
          expect(association.brainstem_key).to eq 'awesomer_users'
        end
      end

      describe 'when :sti_uses_base is true' do
        let(:options) { { sti_uses_base: true } }

        it 'returns the base class name underscored and pluralized' do
          expect(association.brainstem_key).to eq 'users'
        end
      end
    end

    describe 'when the target class is :polymorphic' do
      let(:target_class) { :polymorphic }

      it 'returns nil' do
        expect(association.brainstem_key).to be_nil
      end
    end
  end

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