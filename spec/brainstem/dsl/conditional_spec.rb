require 'spec_helper'
require 'brainstem/dsl/conditional'

describe Brainstem::DSL::Conditional do
  let(:conditional) { Brainstem::DSL::Conditional.new(name, type, action, description) }
  let(:model) { Workspace.first }

  describe '.matches?' do
    context 'as a :model conditional' do
      let(:name) { :title_is_hello }
      let(:type) { :model }
      let(:action) { lambda { |model| model.title == 'hello' } }
      let(:description) { 'visible when the title is hello' }

      it 'calls the action and passes in the given model' do
        model.title = 'not hello'
        expect(conditional.matches?(model)).to be false
        model.title = 'hello'
        expect(conditional.matches?(model)).to be true
      end

      describe 'when given a helper instance' do
        let(:action) { lambda { |model| some_method == 5 } }

        it 'calls the action in the context of the given helper' do
          helper_class = Class.new do
            def some_method
              5
            end
          end
          expect(conditional.matches?(model, helper_class.new)).to be true
        end
      end

      it 'caches in the model conditional cache' do
        hash = { model: {}, request: {} }
        expect(conditional.matches?(model, Object.new, hash)).to be false
        expect(hash).to eq({ model: { title_is_hello: false }, request: {} })

        model.title = 'hello'
        expect(conditional.matches?(model, Object.new, hash)).to be false

        hash = { model: {}, request: {} }
        expect(conditional.matches?(model, Object.new, hash)).to be true
      end
    end

    context 'as a :request conditional' do
      let(:name) { :user_is_bob }
      let(:type) { :request }
      let(:action) { lambda { current_user == 'bob' } }
      let(:description) { 'visible only to bob' }

      it 'calls the action in the helper context, without passing in any arguments' do
        helper_class = Class.new do
          def current_user
            'jane'
          end
        end
        expect(conditional.matches?(model, helper_class.new)).to be false

        helper_class = Class.new do
          def current_user
            'bob'
          end
        end
        expect(conditional.matches?(model, helper_class.new)).to be true
      end

      it 'performs caching' do
        cache = { model: {}, request: {} }

        helper_class = Class.new do
          def current_user
            'jane'
          end
        end
        expect(conditional.matches?(model, helper_class.new, cache)).to be false
        expect(cache[:request][:user_is_bob]).to be false

        helper_class = Class.new do
          def current_user
            'bob'
          end
        end
        expect(conditional.matches?(model, helper_class.new, cache)).to be false

        cache = { model: {}, request: {} }
        expect(conditional.matches?(model, helper_class.new, cache)).to be true
      end
    end
  end
end