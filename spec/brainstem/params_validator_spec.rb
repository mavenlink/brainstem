require 'spec_helper'
require 'brainstem/params_validator'

describe Brainstem::ParamsValidator do
  let(:valid_params_config) do
    {
      sprocket_parent_id: { :_config => { type: 'integer' } },
      sprocket_name:      { :_config => { type: 'string' } }
    }
  end
  let(:action_name) { :create }

  subject { described_class.new(action_name, input_params, valid_params_config) }

  context "when input params has valid keys" do
    let(:input_params) { { sprocket_parent_id: 5, sprocket_name: 'gears' } }

    it "returns true" do
      expect(subject.validate!).to be_truthy
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
      let(:action_name) { :create }

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

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end

        context "when attributes are specified" do
          let(:sub_widget_param) do
            {
              sprocket_parent_id: 15,
              sprocket_name: 'ten gears',
            }
          end

          it "returns true" do
            expect(subject.validate!).to be_truthy
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

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end

        context "when attribute is an empty array" do
          let(:sub_widgets_params) { [] }

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end

        context "when attributes in an array" do
          let(:sub_widgets_params) { [ { sprocket_parent_id: 15, sprocket_name: 'ten gears' } ] }

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end

        skip "(UNSUPPORTED) when attributes in an hash" do
          let(:sub_widgets_params) { { 0 => { title: "child" } } }

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end
      end
    end

    context "when multi nested attributes are valid" do
      let(:valid_params_config) do
        {
          full_name: { :_config => { type: 'string' } },

          permissions: {
            :_config => { type: 'hash' },
            can_edit: { :_config => { type: 'boolean' } },
          },

          skills: {
            :_config => { type: 'array', item_type: 'hash' },
            name: { :_config => { type: 'string' } },
            category: {
              :_config => { type: 'hash' },

              name: { :_config => { type: 'string' } }
            }
          }
        }
      end

      let(:input_params) {
        {
          full_name: 'Buzz Killington',
          permissions: { can_edit: true },
          skills: [
            { name: 'Ruby', category: { name: 'Programming' } },
            { name: 'Karate', category: { name: 'Self Defense' } }
          ]
        }
      }

      it "returns true" do
        expect(subject.validate!).to be_truthy
      end

      context "when expected param is a hash" do
        context "when value is nil" do
          let(:input_params) {
            {
              permissions: nil,
            }
          }

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end
      end

      context "when expected param is an array" do
        context "when value is nil" do
          let(:input_params) {
            {
              skills: nil
            }
          }

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end

        context "when value is an empty array" do
          let(:input_params) {
            {
              skills: []
            }
          }

          it "returns true" do
            expect(subject.validate!).to be_truthy
          end
        end
      end
    end
  end

  context "when input parameters are invalid" do
    context "with an empty hash" do
      let(:input_params) { {} }

      it "raises an missing params error" do
        expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
      end
    end

    context "with a non-hash object" do
      let(:input_params) { [{ foo: "bar" }] }

      it "raises an missing params error" do
        expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
      end
    end

    context "with nil" do
      let(:input_params) { nil }

      it "raises an missing params error" do
        expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
      end
    end
  end

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
      expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
    end
  end

  context "when input params have unknown keys" do
    let(:input_params) { { my_cool_param: "something" } }

    it "lists unknown params" do
      expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
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
        context "when recursive attribute has invalid keys" do
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
            expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
          end
        end

        context "when attribute is an empty hash" do
          let(:input_params) do
            {
              sprocket_parent_id: 5,
              sprocket_name: 'gears',
              sub_widget: {}
            }
          end

          it "raises an error" do
            expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
          end
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
          expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
        end
      end
    end

    context "when multi nested attributes are invalid" do
      let(:restrict_to_actions) { [] }
      let(:valid_params_config) do
        {
          full_name: { :_config => { type: 'string' } },

          permissions: {
            :_config => { type: 'hash', only: restrict_to_actions },

            can_edit: { :_config => { type: 'boolean' } },
          },

          skills: {
            :_config => { type: 'array', item_type: 'hash' },

            name: { :_config => { type: 'string', only: restrict_to_actions } },
            category: {
              :_config => { type: 'hash' },

              name: { :_config => { type: 'string' } }
            }
          }
        }
      end
      let(:input_params) { { sprocket_parent_id: 5, sprocket_name: 'gears' } }

      context "when params are supplied to the wrong action" do
        let(:action) { :create }
        let(:restrict_to_actions) { [:update] }
        let(:input_params) {
          {
            full_name: 'Buzz Killington',
            permissions: { can_edit: true },
            skills: [
              { name: 'Ruby', category: { name: 'Programming' } },
              { name: 'Kaarate', category: { name: 'Self Defense' } }
            ]
          }
        }

        it "raises an error" do
          expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
        end
      end

      context "when unknown params are present" do
        context "when present in a hash" do
          let(:input_params) {
            {
              full_name: 'Buzz Killington',
              permissions: { can_edit: true, invalid: 'blah' },
              skills: [
                { name: 'Ruby', category: { name: 'Programming' } },
                { name: 'Kaarate', category: { name: 'Self Defense' } }
              ]
            }
          }

          it "raises an error" do
            expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
          end
        end

        context "when present in an array" do
          let(:input_params) {
            {
              full_name: 'Buzz Killington',
              permissions: { can_edit: true },
              skills: [
                { name: 'Ruby', category: { invalid: 'blah' } },
                { name: 'Kaarate', category: { name: 'Self Defense' } }
              ]
            }
          }

          it "raises an error" do
            expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
          end
        end
      end

      context "when params are malformed" do
        context "when expected to be an array" do
          context "when given an array with an empty hash" do
            let(:input_params) {
              {
                skills: [
                  { name: 'Ruby', category: { invalid: 'blah' } },
                  {},
                ]
              }
            }

            it "raises an error" do
              expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
            end
          end

          context "when given a hash" do
            let(:input_params) {
              {
                skills: {},
              }
            }

            it "raises an error" do
              expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
            end
          end
        end

        context "when expected to be a hash" do
          context "when given an array" do
            let(:input_params) {
              {
                permissions: [ { can_edit: true } ]
              }
            }

            it "raises an error" do
              expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
            end
          end

          context "when given an empty hash" do
            let(:input_params) {
              {
                permissions: {},
              }
            }

            it "raises an error" do
              expect { subject.validate! }.to raise_error(Brainstem::ValidationError)
            end
          end
        end
      end
    end
  end
end
