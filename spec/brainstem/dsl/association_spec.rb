require 'spec_helper'
require 'brainstem/dsl/association'

describe Brainstem::DSL::Association do
  let(:name) { :user }
  let(:target_class) { User }
  let(:description) { "This object's user" }
  let(:options) { { info: description } }
  let(:association) { Brainstem::DSL::Association.new(name, target_class, options) }

  describe 'description' do
    context 'when `info` is specified in the options' do
      it 'returns the value specified with the info key' do
        expect(association.description).to eq(description)
      end
    end

    context 'when `info` is not specified in the options' do
      let(:options) { {} }

      it 'returns nil' do
        expect(association.description).to be_nil
      end
    end
  end

  describe "#run_on" do
    let(:context) { { } }

    context 'with no special options' do
      it 'calls the method by name on the model' do
        object = Object.new
        mock(object).user
        association.run_on(object, context)
      end
    end

    context 'when given a via' do
      let(:options) { { via: :user2 } }

      it 'calls the method named in :via on the model' do
        object = Object.new
        mock(object).user2
        association.run_on(object, context)
      end
    end

    context 'when given a dynamic lambda' do
      let(:options) { { dynamic: lambda { |model| some_instance_method; :return_value } } }

      it 'calls the lambda in the context of the given instance' do
        instance = Object.new
        mock(instance).some_instance_method
        expect(association.run_on(:anything, context, instance)).to eq :return_value
      end
    end

    context 'when given a lookup lambda' do
      let(:options) { { lookup: lambda { |models| some_instance_method; Hash[models.map { |model| [model.id, model.username] }] } } }
      let(:first_model) { target_class.create(username: 'Ben') }
      let(:second_model) { target_class.create(username: 'Nate') }
      let(:models) { [first_model, second_model] }
      let(:context) {
        {
          lookup: Brainstem::Presenter.new.send(:empty_lookup_cache, [], [name.to_s]),
          models: models
        }
      }
      # {:lookup=>{:fields=>{}, :associations=>{"user"=>nil}}}

      context 'The first model is ran' do
        it 'builds lookup cache and returns the value for the first model' do
          expect(context[:lookup][:associations][name.to_s]).to eq(nil)
          instance = Object.new
          mock(instance).some_instance_method
          expect(association.run_on(first_model, context, instance)).to eq('Ben')
          expect(context[:lookup][:associations][name.to_s]).to eq({ first_model.id => 'Ben', second_model.id => 'Nate' })
        end
      end

      context 'The second model is ran after the first' do
        it 'returns the value from the lookup cache and does not run the lookup' do
          instance = Object.new
          mock(instance).some_instance_method
          association.run_on(first_model, context, instance)
          expect(context[:lookup][:associations][name.to_s]).to eq({ first_model.id => 'Ben', second_model.id => 'Nate' })

          mock(instance).some_instance_method.never
          expect(association.run_on(second_model, context, instance)).to eq('Nate')
        end
      end

      context 'with no lookup_fetch' do
        context 'when the lookup returns on object which does not respond to []' do
          let(:options) { { lookup: lambda { |models| nil } } }

          it 'should raise error explaining the default lookup fetch relies on [] to access the model\'s value from the lookup' do
            expect {
              association.run_on(first_model, context)
            }.to raise_error(StandardError, 'Brainstem expects the return result of the `lookup` to be a Hash since it must respond to [] in order to access the model\'s assocation(s). Default: lookup_fetch: lambda { |lookup, model| lookup[model.id] }`')
          end
        end
      end

      context 'with a dynamic lambda' do
        let(:options) {
          {
            lookup: lambda { |models| lookup_instance_method; Hash[models.map { |model| [model.id, model.username] }] },
            dynamic: lambda { |model| dynamic_instance_method; model.username }
          }
        }

        it 'calls the lookup lambda and not the dynamic lambda' do
          instance = Object.new
          mock(instance).dynamic_instance_method.never
          mock(instance).lookup_instance_method
          expect(association.run_on(first_model, context, instance)).to eq 'Ben'
        end
      end

      context 'when given a lookup_fetch' do
        let(:options) {
          {
            lookup: lambda { |models| Hash[models.map { |model| [model.id, model.username] }] },
            lookup_fetch: lambda { |lookup, model| some_instance_method; lookup[model.id] }
          }
        }

        it 'returns the value from the lookup using the lookup_fetch lambda' do
          context[:lookup][:associations][name.to_s] = {}
          context[:lookup][:associations][name.to_s][first_model.id] = "Ben's stubbed out Name"
          instance = Object.new
          mock(instance).some_instance_method
          expect(association.run_on(first_model, context, instance)).to eq("Ben's stubbed out Name")
        end
      end
    end
  end
end
