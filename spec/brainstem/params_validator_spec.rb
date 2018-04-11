require 'spec_helper'
require 'brainstem/params_validator'

describe Brainstem::ParamsValidator do
  let(:valid_params_config) do
    {
      sprocket_parent_id: { :_config => { type: 'integer' } },
      sprocket_name:      { :_config => { type: 'string' } }
    }
  end
  let(:options) { {} }
  let(:action_name) { :create }

  subject { described_class.new(action_name, input_params, valid_params_config, options) }

  context "when input params has valid keys" do
    let(:input_params) { { sprocket_parent_id: 5, sprocket_name: 'gears' } }

    it "returns sanitized params" do
      expect(subject.validate!).to eq(input_params)
    end

    context "when recursive attribute is given" do
      let(:valid_params_config) do
        {
          sprocket_parent_id: { :_config => { type: 'integer' } },
          sprocket_name:      { :_config => { type: 'string' } },
          sub_widget:         { :_config => { type: 'hash', recursive: true } },
          sub_widgets:        { :_config => { type: 'array', item_type: 'hash', recursive: true } },
        }
      end
      let(:action) { :create }

      context "when recursive attribute is a hash" do
        let(:input_params) do
          {
            sprocket_parent_id: 5,
            sprocket_name: 'gears',
            sub_widget: sub_widget_param
          }
        end

        context "when attribute is nil" do
          let(:sub_widget_param) { nil }

          it "returns the sanitized attributes without the empty recursive param" do
            expect(subject.validate!).to eq(input_params.except(:sub_widget))
          end
        end

        context "when attribute is an empty hash" do
          let(:sub_widget_param) { {} }

          it "returns the sanitized attributes without the empty recursive param" do
            expect(subject.validate!).to eq(input_params.except(:sub_widget))
          end
        end

        context "when attributes are specified" do
          let(:sub_widget_param) do
            {
              sprocket_parent_id: 15,
              sprocket_name: 'ten gears',
            }
          end

          it "returns the sanitized attributes" do
            expect(subject.validate!).to eq(input_params)
          end
        end
      end

      context "when recursive attribute is an array" do
        let(:input_params) do
          {
            sprocket_parent_id: 5,
            sprocket_name: 'gears',
            sub_widgets: sub_widgets_params
          }
        end

        context "when attribute is nil" do
          let(:sub_widgets_params) { nil }

          it "returns the sanitized attributes without the empty recursive param" do
            expect(subject.validate!).to eq(input_params.except(:sub_widgets))
          end
        end

        context "when attribute is an empty array" do
          let(:sub_widgets_params) { [] }

          it "returns the sanitized attributes without the empty recursive param" do
            expect(subject.validate!).to eq(input_params.except(:sub_widgets))
          end
        end

        context "when attributes in an array" do
          let(:sub_widgets_params) { [ { sprocket_parent_id: 15, sprocket_name: 'ten gears' } ] }

          it "returns the sanitized attributes" do
            expect(subject.validate!).to eq(input_params)
          end
        end

        skip "(UNSUPPORTED) when attributes in an hash" do
          let(:sub_widgets_params) { { 0 => { title: "child" } } }

          it "returns the sanitized attributes" do
            expect(subject.validate!).to eq(input_params)
          end
        end
      end
    end
  end

  context "when input parameters are invalid" do
    context "with an empty hash" do
      let(:input_params) { {} }

      it "raises an missing params error" do
        expect { subject.validate! }.to raise_error(Brainstem::UnknownParams)
      end
    end

    context "with a non-hash object" do
      let(:input_params) { [{ foo: "bar" }] }

      it "raises an missing params error" do
        expect { subject.validate! }.to raise_error(Brainstem::UnknownParams)
      end
    end

    context "with nil" do
      let(:input_params) { nil }

      it "raises an missing params error" do
        expect { subject.validate! }.to raise_error(Brainstem::UnknownParams)
      end
    end
  end

  context "when `ignore_unknown_fields` is true" do
    let(:options) { { ignore_unknown_fields: true } }

    context "when params are supplied to the wrong action" do
      let(:valid_params_config) do
        {
          sprocket_parent_id: { :_config => { type: 'integer', only: [:update] } },
          sprocket_name:      { :_config => { type: 'string' } }
        }
      end
      let(:input_params) { { sprocket_parent_id: 5, sprocket_name: 'gears' } }
      let(:action) { :create }

      it "returns the input params without the unknown params" do
        expect(subject.validate!).to eq(input_params.except(:sprocket_parent_id))
      end
    end

    context "when input params have unknown keys" do
      let(:input_params) { { my_cool_param: "something" } }

      it "returns the input params without the unknown params" do
        expect(subject.validate!).to eq(input_params.except(:my_cool_param))
      end

      context "when recursive attribute has invalid / unknown values" do
        let(:valid_params_config) do
          {
            sprocket_parent_id: { :_config => { type: 'integer' } },
            sprocket_name:      { :_config => { type: 'string' } },
            sub_widget:         { :_config => { type: 'hash', recursive: true } },
            sub_widgets:        { :_config => { type: 'array', item_type: 'hash', recursive: true } },
          }
        end

        context "when recursive attribute is a hash" do
          let(:input_params) do
            {
              sprocket_parent_id: 5,
              sprocket_name: 'gears',
              sub_widget: {
                invalid_id: 15,
                sprocket_name: 'ten gears',
              }
            }
          end

          it "returns the input params without the unknown params" do
            expect(subject.validate!).to eq({
              sprocket_parent_id: 5,
              sprocket_name: 'gears',
              sub_widget: {
                sprocket_name: 'ten gears',
              }
            })
          end
        end

        context "when recursive attribute is an array" do
          let(:input_params) do
            {
              sprocket_parent_id: 5,
              sprocket_name: 'gears',
              sub_widgets: [
                { invalid_id: 15, sprocket_name: 'ten gears' }
              ]
            }
          end

          it "returns the input params without the unknown params" do
            expect(subject.validate!).to eq({
              sprocket_parent_id: 5,
              sprocket_name: 'gears',
              sub_widgets: [
                { sprocket_name: 'ten gears' }
              ]
            })
          end
        end
      end
    end
  end

  context "when `ignore_unknown_fields` is false" do
    context "when params are supplied to the wrong action" do
      let(:valid_params_config) do
        {
          sprocket_parent_id: { :_config => { type: 'integer', only: [:update] } },
          sprocket_name:      { :_config => { type: 'string' } }
        }
      end
      let(:input_params) { { sprocket_parent_id: 5, sprocket_name: 'gears' } }
      let(:action) { :create }

      it "throws an unknown params error" do
        expect { subject.validate! }.to raise_error(Brainstem::UnknownParams)
      end
    end

    context "when input params have unknown keys" do
      let(:input_params) { { my_cool_param: "something" } }

      it "lists unknown params" do
        expect { subject.validate! }.to raise_error(Brainstem::UnknownParams)
      end

      context "when recursive attribute has invalid / unknown properties" do
        let(:valid_params_config) do
          {
            sprocket_parent_id: { :_config => { type: 'integer' } },
            sprocket_name:      { :_config => { type: 'string' } },
            sub_widget:         { :_config => { type: 'hash', recursive: true } },
            sub_widgets:        { :_config => { type: 'array', item_type: 'hash', recursive: true } },
          }
        end

        context "when recursive attribute is a hash" do
          let(:input_params) do
            {
              sprocket_parent_id: 5,
              sprocket_name: 'gears',
              sub_widget: {
                invalid_id: 15,
                sprocket_name: 'ten gears',
              }
            }
          end

          it "raises an error" do
            expect { subject.validate! }.to raise_error(Brainstem::UnknownParams)
          end
        end

        context "when recursive attribute is an array" do
          let(:input_params) do
            {
              sprocket_parent_id: 5,
              sprocket_name: 'gears',
              sub_widgets: [
                { invalid_id: 15, sprocket_name: 'ten gears' }
              ]
            }
          end

          it "raises an error" do
            expect { subject.validate! }.to raise_error(Brainstem::UnknownParams)
          end
        end
      end
    end
  end
end
