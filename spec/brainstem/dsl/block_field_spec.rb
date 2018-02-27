require 'spec_helper'
require 'brainstem/dsl/block_field'

describe Brainstem::DSL::BlockField do
  let(:name)         { :tasks }
  let(:type)         { :hash }
  let(:description)  { 'the title of this model' }
  let(:options)      { { info: description } }
  let(:nested_field) { Brainstem::DSL::BlockField.new(name, type, options) }

  describe 'self.for' do
    subject { described_class.for(name, type, options) }

    context 'when given an array type' do
      let(:type) { :array }

      it 'returns a new ArrayBlockField' do
        expect(subject).to be_instance_of(Brainstem::DSL::ArrayBlockField)
      end
    end

    context 'when given a hash type' do
      let(:type) { :hash }

      it 'returns a new HashBlockField' do
        expect(subject).to be_instance_of(Brainstem::DSL::HashBlockField)
      end
    end

    context 'when given an unknown type' do
      let(:type) { :unknown }

      it 'raises an error' do
        expect { subject }.to raise_error(StandardError)
      end
    end
  end

  describe 'use_parent_value?' do
    let(:field) { Brainstem::DSL::Field.new(:type, type, options) }

    subject { nested_field.use_parent_value?(field) }

    context 'when sub field does not specify use_parent_value option' do
      let(:options) { { info: description } }

      it { is_expected.to be_truthy }
    end

    context 'when sub field specifies use_parent_value option' do
      let(:options) { { use_parent_value: use_parent_value } }

      context 'when set to true' do
        let(:use_parent_value) { true }

        it { is_expected.to be_truthy }
      end

      context 'when set to false' do
        let(:use_parent_value) { false }

        it { is_expected.to be_falsey }
      end
    end
  end
end
