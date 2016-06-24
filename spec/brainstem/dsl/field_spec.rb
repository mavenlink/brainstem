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
    let(:context) { { } }

    context 'on :dynamic fields' do
      let(:options) { { dynamic: lambda { some_instance_method } } }

      it 'calls the :dynamic lambda in the context of the given instance' do
        do_not_allow(model).title
        instance = Object.new
        mock(instance).some_instance_method
        field.run_on(model, context, instance)
      end
    end

    context 'on :lookup fields' do
      let(:options) { { lookup: lambda { |models| some_instance_method; Hash[models.map { |model| [model.id, model.title] }] } } }
      let(:first_model) { Workspace.create(title: "Ben's Project") }
      let(:second_model) { Workspace.create(title: "Nate's Project") }
      let(:models) { [first_model, second_model] }
      let(:context) {
        {
          lookup: Brainstem::Presenter.new.send(:empty_lookup_cache, [name.to_s], []),
          models: models
        }
      }
      # {:lookup=>{:fields=>{"title"=>nil}, :associations=>{}}

      context 'The first model is ran' do
        it 'builds lookup cache and returns the value for the first model' do
          expect(context[:lookup][:fields][name.to_s]).to eq(nil)
          instance = Object.new
          mock(instance).some_instance_method
          expect(field.run_on(first_model, context, instance)).to eq("Ben's Project")
          expect(context[:lookup][:fields][name.to_s]).to eq({ first_model.id => "Ben's Project", second_model.id => "Nate's Project" })
        end
      end

      context 'The second model is ran after the first' do
        it 'returns the value from the lookup cache and does not run the lookup' do
          instance = Object.new
          mock(instance).some_instance_method
          field.run_on(first_model, context, instance)
          expect(context[:lookup][:fields][name.to_s]).to eq({ first_model.id => "Ben's Project", second_model.id => "Nate's Project" })

          mock(instance).some_instance_method.never
          expect(field.run_on(second_model, context, instance)).to eq("Nate's Project")
        end
      end

      context 'with no lookup_fetch' do
        context 'when the lookup returns on object which does not respond to []' do
          let(:options) { { lookup: lambda { |models| nil } } }

          it 'should raise error explaining the default lookup fetch relies on [] to access the model\'s value from the lookup' do
            expect {
              field.run_on(first_model, context)
            }.to raise_error(StandardError, 'Brainstem expects the return result of the `lookup` to be a Hash since it must respond to [] in order to access the model\'s assocation(s). Default: lookup_fetch: lambda { |lookup, model| lookup[model.id] }`')
          end
        end
      end

      context 'with a dynamic lambda' do
        let(:options) {
          {
            lookup: lambda { |models| lookup_instance_method; Hash[models.map { |model| [model.id, model.title] }] },
            dynamic: lambda { |model| dynamic_instance_method; model.title }
          }
        }

        context 'when presenting one model' do
          let(:models) { [first_model] }

          it 'calls the dynamic lambda and not the lookup lambda' do
            instance = Object.new
            mock(instance).dynamic_instance_method
            mock(instance).lookup_instance_method.never
            expect(field.run_on(first_model, context, instance)).to eq "Ben's Project"
          end
        end

        context 'when presenting more than one model' do
          it 'calls the lookup lambda and not the dynamic lambda' do
            instance = Object.new
            mock(instance).lookup_instance_method
            mock(instance).dynamic_instance_method.never
            expect(field.run_on(first_model, context, instance)).to eq "Ben's Project"
          end
        end
      end

      context 'on :lookup_fetch' do
        let(:options) {
          {
            lookup: lambda { |models| Hash[models.map { |model| [model.id, model.title] }] },
            lookup_fetch: lambda { |lookup, model| some_instance_method; lookup[model.id] }
          }
        }

        it 'returns the value from the lookup using the lookup_fetch lambda' do
          context[:lookup][:fields][name.to_s] = {}
          context[:lookup][:fields][name.to_s][first_model.id] = "Ben's stubbed out Project"
          instance = Object.new
          mock(instance).some_instance_method
          expect(field.run_on(first_model, context, instance)).to eq("Ben's stubbed out Project")
        end
      end
    end

    context 'on non-:dynamic fields' do
      it 'calls method_name on the model' do
        mock(model).foo
        mock(field).method_name { 'foo' }
        field.run_on(model, context)
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

  describe "#optioned?" do
    context "when is not an optional field" do
      it 'returns true' do
        expect(field.optioned?(['some_optional_field', 'some_other_optional_field'])).to eq true
      end
    end

    context "when is an optional field" do
      let(:name) { :expensive_title }
      let(:type) { :string }
      let(:options) { { optional: true } }
      let(:description) { 'the optional expensive title field' }

      context "when not requested" do
        it 'returns false' do
          expect(field.optioned?([])).to eq false
        end
      end

      context "when requested" do
        it 'returns true' do
          expect(field.optioned?(['expensive_title', 'some_other_optional_field'])).to eq true
        end
      end
    end
  end
end
