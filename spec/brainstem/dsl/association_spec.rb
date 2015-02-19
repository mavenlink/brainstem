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
        expect(association.brainstem_key).to eq :my_users
      end
    end

    describe 'when a target class is present' do
      class AwesomeUser < ActiveRecord::Base
      end

      let(:target_class) { AwesomeUser }

      it 'returns it underscored and pluralized' do
        expect(association.brainstem_key).to eq :awesome_users
      end
    end

    describe 'when a STI class is present' do
      class AwesomerUser < User
      end

      let(:target_class) { AwesomerUser }

      describe 'by default' do
        it 'returns the subclass name underscored and pluralized' do
          expect(association.brainstem_key).to eq :awesomer_users
        end
      end

      describe 'when :sti_uses_base is true' do
        let(:options) { { sti_uses_base: true } }

        it 'returns the base class name underscored and pluralized' do
          expect(association.brainstem_key).to eq :users
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

  describe '#load_records_into_hash!' do
    let(:record_hash) { { } }
    let(:post1) { Post.all[0] }
    let(:post2) { Post.all[1] }

    it 'fills the hash' do
      association.load_records_into_hash!([post1, post2], record_hash)
      expect(record_hash[:users]).to eq [post1.user, post2.user]
    end

    context 'on a polymorphic association' do
      let(:target_class) { :polymorphic }
      let(:name) { :subject }

      before do
        Workspace.find(1).update_attribute :type, 'SubWorkspace'
      end

      it 'fills the hash with the model names' do
        association.load_records_into_hash!([post1, post2], record_hash)
        expect(record_hash[:sub_workspaces]).to eq [Workspace.first]
        expect(record_hash[:workspaces]).to be_nil
        expect(record_hash[:tasks]).to eq [Task.first]
      end

      describe 'using :sti_uses_base' do
        let(:options) { { sti_uses_base: true } }

        it 'fills the hash with the model names, using their base classes' do
          association.load_records_into_hash!([post1, post2], record_hash)
          expect(record_hash[:sub_workspaces]).to be_nil
          expect(record_hash[:workspaces]).to eq [Workspace.first]
          expect(record_hash[:tasks]).to eq [Task.first]
        end
      end
    end

    it 'creates the key, even when no models are present' do
      association.load_records_into_hash!([], record_hash)
      expect(record_hash[:users]).to eq []
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
      let(:options) { { dynamic: lambda { |model| expect(model).to eq(:anything); :return_value } } }

      it 'calls the lambda' do
        expect(association.run_on(:anything)).to eq :return_value
      end
    end
  end
end