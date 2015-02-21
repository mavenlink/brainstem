require 'spec_helper'
require 'brainstem/dsl/field'

describe Brainstem::DSL::Field do
  let(:name) { :title }
  let(:type) { :string }
  let(:description) { 'the title of this Workspace' }
  let(:options) { { } }
  let(:field) { Brainstem::DSL::Field.new(name, type, description, options) }

  describe '#method_name' do
    describe 'by default' do
      it 'returns the name' do
        expect(field.method_name).to eq :title
      end
    end

    describe 'on dynamic fields' do
      let(:options) { { dynamic: lambda { 2 } } }

      it 'returns nil' do
        expect(field.method_name).to be_nil
      end
    end

    describe 'when :via is present' do
      let(:options) { { via: :description } }

      it 'uses the :via method name' do
        expect(field.method_name).to eq :description
      end
    end
  end

  describe '#run_on' do
    let(:workspace) { Workspace.first }

    context 'on :dynamic fields' do
      let(:options) { { dynamic: lambda { some_instance_method } } }

      it 'calls the :dynamic lambda in the context of the given instance' do
        do_not_allow(workspace).title
        instance = Object.new
        mock(instance).some_instance_method
        field.run_on(workspace, instance)
      end
    end

    context 'on non-:dynamic fields' do
      it 'calls method_name on the model' do
        mock(workspace).foo
        mock(field).method_name { :foo }
        field.run_on(workspace)
      end
    end
  end
end