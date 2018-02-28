require 'spec_helper'
require 'brainstem/dsl/hash_block_field'

describe Brainstem::DSL::HashBlockField do
  let(:name)         { :tasks }
  let(:type)         { :hash }
  let(:description)  { 'the title of this model' }
  let(:options)      { { info: description } }
  let(:nested_field) { Brainstem::DSL::HashBlockField.new(name, type, options) }
  let(:model)        { Workspace.find(1) }
  let(:lead_user)    { model.lead_user }

  before do
    expect(lead_user).to be_present
    expect(nested_field.configuration.keys).to be_empty

    # Add sub fields to the hash block field.
    nested_field.configuration[:type] = Brainstem::DSL::Field.new(:type, type, {})
    nested_field.configuration[:formatted_type] = Brainstem::DSL::Field.new(:formatted_type, type,
      dynamic: -> (model) { "Formatted #{model.type}" },
      use_parent_value: true
    )
    nested_field.configuration[:secret] = Brainstem::DSL::Field.new(:secret, type,
      via: :secret_info,
      use_parent_value: false
    )

    expect(nested_field.configuration.keys).to eq(%w(type formatted_type secret))
  end

  describe '#run_on' do
    let(:context)              { { } }
    let(:helper_instance)      { Object.new }

    describe 'when none of the sub-fields are presentable' do
      before do
        stub.any_instance_of(Brainstem::DSL::Field).presentable? { false }
      end

      it 'presents an empty hash' do
        presented_data = nested_field.run_on(model, context)

        expect(presented_data).to eq({})
      end
    end

    describe 'when the field is executable' do
      let(:name) { :lead_user }
      let(:options) { { info: description, via: :lead_user } }

      before do
        expect(nested_field.send(:executable?, model)).to be_truthy

        expect(nested_field.configuration[:type].options[:use_parent_value]).to be_nil
        expect(nested_field.configuration[:formatted_type].options[:use_parent_value]).to be_truthy
      end

      it 'returns a hash with the value from the evaluated parent' do
        presented_data = nested_field.run_on(model, context)

        expect(presented_data['type']).to eq(lead_user.type)
        expect(presented_data['formatted_type']).to eq("Formatted #{lead_user.type}")
      end

      context 'when the sub field doesn\'t use a parent value' do
        before do
          expect(nested_field.configuration[:secret].options[:use_parent_value]).to be_falsey
        end

        it 'returns a hash with the value from itself' do
          presented_data = nested_field.run_on(model, context)

          expect(presented_data['secret']).to eq(model.secret_info)
        end
      end
    end

    describe 'when the field delegates to its parent' do
      let(:name) { :klass }

      before do
        expect(nested_field.send(:executable?, model)).to be_falsey

        expect(nested_field.configuration[:type].options[:use_parent_value]).to be_nil
        expect(nested_field.configuration[:formatted_type].options[:use_parent_value]).to be_truthy
      end

      it 'returns a hash with the value from its parent' do
        presented_data = nested_field.run_on(model, context)

        expect(presented_data['type']).to eq(model.type)
        expect(presented_data['formatted_type']).to eq("Formatted #{model.type}")
      end

      context 'when the sub field doesn\'t use a parent value' do
        before do
          expect(nested_field.configuration[:secret].options[:use_parent_value]).to be_falsey
        end

        it 'returns a hash with the value from itself' do
          presented_data = nested_field.run_on(model, context)

          expect(presented_data['secret']).to eq(model.secret_info)
        end
      end
    end
  end

  describe '#executable' do
    subject { nested_field.executable?(model) }

    context 'when dynamic option is specified' do
      let(:options) { { dynamic: -> { [] } } }

      it { is_expected.to be_truthy }
    end

    context 'when lookup option is specified' do
      let(:options) { { lookup: -> { [] } } }

      it { is_expected.to be_truthy }
    end

    context 'when via option is specified' do
      let(:options) { { via: :foo } }

      it { is_expected.to be_truthy }
    end

    context 'when dynamic option is specified' do
      let(:options) { {} }

      it { is_expected.to be_falsey }
    end
  end
end
