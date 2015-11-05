require 'spec_helper'
require 'brainstem/concerns/error_presentation'

describe Brainstem::Concerns::ErrorPresentation do
  class ErrorsController
    include Brainstem::Concerns::ErrorPresentation
  end

  let(:controller) { ErrorsController.new }

  describe "#brainstem_system_error" do
    let(:options) { { type: :other } }

    it "accepts a list of messages" do
      error_response = {errors: [{type: :system, message: "error1"}, {type: :system, message: "error2"}]}
      expect(controller.brainstem_system_error("error1", "error2")).to eq(error_response)
      expect(controller.brainstem_system_error(["error1", "error2"])).to eq(error_response)
    end

    it "accepts an options hash as last argument" do
      error_response = {errors: [{type: :other, message: "error1"}, {type: :other, message: "error2"}]}
      expect(controller.brainstem_system_error("error1", "error2", options)).to eq(error_response)
      expect(controller.brainstem_system_error(["error1", "error2"], options)).to eq(error_response)
    end
  end

  describe "#brainstem_model_error" do
    context 'with a Hash or Hashes' do
      it 'has a default type' do
        expect(controller.brainstem_model_error({ message: 'hello', field: 'some_field' })).to eq({ errors: [ { message: 'hello', type: 'validation', field: 'some_field' } ] })
        expect(controller.brainstem_model_error([{ message: 'hello1', field: 'some_field1' }, { message: 'hello2', field: 'some_field2' }])).to eq({
          errors: [
            { message: 'hello1', type: 'validation', field: 'some_field1' },
            { message: 'hello2', type: 'validation', field: 'some_field2' }
          ]
        })
      end

      it 'can override the type' do
        expect(controller.brainstem_model_error({ message: 'something', type: 'foo' })[:errors].first[:type]).to eq 'foo'
      end

      it 'raises an ArgumentError when no message is given' do
        expect { controller.brainstem_model_error({ type: 'foo' }) }.to raise_error(ArgumentError, /message required/)
      end
    end

    it 'can handle a String' do
      expect(controller.brainstem_model_error("hello")).to eq({ errors: [ { message: 'hello', type: 'validation', field: :base } ] })
      expect(controller.brainstem_model_error(["hello", "world"])).to eq({
        errors: [
          { message: 'hello', type: 'validation', field: :base },
          { message: 'world', type: 'validation', field: :base }
        ]
      })
    end

    context 'with models' do
      class Model
        include ActiveModel::Validations
      end

      it 'can handle a single Model' do
        model = Model.new
        model.errors.add(:title, 'must be present')
        expect(controller.brainstem_model_error(model)).to eq({ errors: [ { message: 'Title must be present', type: 'validation', field: :title, index: 0 } ] })
      end
  
      it 'can handle an array of Models' do
        model1 = Model.new
        model1.errors.add(:title, 'must be present')
        model2 = Model.new
        model2.errors.add(:foo, 'cannot be blank')
        model2.errors.add(:base, 'This model is invalid')
        
        expect(controller.brainstem_model_error([model1, model2])).to eq({
          errors: [
            { message: 'Title must be present', type: 'validation', field: :title, index: 0 },
            { message: 'Foo cannot be blank', type: 'validation', field: :foo, index: 1 },
            { message: 'This model is invalid', type: 'validation', field: :base, index: 1 },
          ]
        })
      end
  
      it 'can rewrite from internal to external field names' do
        model = Model.new
        model.errors.add(:title, 'must be present')
        model.errors.add(:foo, 'cannot be blank')
        
        expect(controller.brainstem_model_error(model, rewrite_params: { external_title: :title })).to eq({
          errors: [
            { message: 'Title must be present', type: 'validation', field: :external_title, index: 0 },
            { message: 'Foo cannot be blank', type: 'validation', field: :foo, index: 0 },
          ]
        })
      end

      it 'handles magic ^ in error message' do
        model = Model.new
        model.errors.add(:title, '^Your thing must have a title')

        expect(controller.brainstem_model_error(model)).to eq({
          errors: [
            message:  'Your thing must have a title',
            type:     'validation',
            field:    :title,
            index:    0,
          ]
        })
      end
    end
  end
end
