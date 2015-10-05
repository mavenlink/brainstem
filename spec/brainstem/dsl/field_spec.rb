require 'spec_helper'
require 'brainstem/dsl/field'

describe Brainstem::DSL::Field do
  let(:name) { :title }
  let(:type) { :string }
  let(:description) { 'the title of this model' }
  let(:options) { { } }
  let(:field) { Brainstem::DSL::Field.new(name, type, description, options) }
  let(:model) { Workspace.first }

  describe '#method_name' do
    describe 'by default' do
      it 'returns the name' do
        expect(field.method_name).to eq 'title'
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
        expect(field.method_name).to eq 'description'
      end
    end
  end

  describe '#run_on' do
    context 'on :dynamic fields' do
      let(:options) { { dynamic: lambda { some_instance_method } } }

      it 'calls the :dynamic lambda in the context of the given instance' do
        do_not_allow(model).title
        instance = Object.new
        mock(instance).some_instance_method
        field.run_on(model, instance)
      end
    end

    context 'on non-:dynamic fields' do
      it 'calls method_name on the model' do
        mock(model).foo
        mock(field).method_name { 'foo' }
        field.run_on(model)
      end
    end
  end

  describe '#conditionals_match?' do
    let(:fake_conditional) do
      Class.new do
        def initialize(result)
          @result = result
        end

        def matches?(model, helper_instance, conditional_cache)
          @result
        end
      end
    end

    context 'when no :if option has been set on the field' do
      it 'returns true when there are no conditions' do
        expect(field.conditionals_match?(model, WorkspacePresenter.configuration[:conditionals])).to eq true
      end
    end

    context 'when a single :if has been set' do
      let(:options) { { if: :title_is_hello } }

      it 'returns true if the conditional matches' do
        expect(field.conditionals_match?(model, title_is_hello: fake_conditional.new(true))).to eq true
      end

      it 'returns false if the conditional does not match' do
        expect(field.conditionals_match?(model, title_is_hello: fake_conditional.new(false))).to eq false
      end
    end

    context 'when multiple :if options have been passed' do
      let(:options) { { if: [:title_is_hello, :user_is_bob] } }

      it 'returns true if all of the conditionals match' do
        expect(field.conditionals_match?(model, title_is_hello: fake_conditional.new(true), user_is_bob: fake_conditional.new(false))).to eq false
        expect(field.conditionals_match?(model, title_is_hello: fake_conditional.new(false), user_is_bob: fake_conditional.new(true))).to eq false
        expect(field.conditionals_match?(model, title_is_hello: fake_conditional.new(true), user_is_bob: fake_conditional.new(true))).to eq true
        expect(field.conditionals_match?(model,
                                         unknown: fake_conditional.new(false),
                                         title_is_hello: fake_conditional.new(true),
                                         user_is_bob: fake_conditional.new(true))).to eq true
      end
    end
  end
end