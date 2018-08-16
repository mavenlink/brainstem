require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/presenter_formatter'
require 'brainstem/api_docs/presenter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          describe PresenterFormatter do
            let(:presenter_args)        { {} }
            let(:extra_presenter_args)  { {} }
            let(:presenter)             { Presenter.new(presenter_args.merge(extra_presenter_args)) }
            let(:nodoc)                 { false }
            let(:title)                 { 'Sprocket' }
            let(:presented_class)       { 'Sprocket' }
            let(:lorem)                 { 'Best description ever' }
            let(:valid_fields)          { { title: OpenStruct.new(name: :title, type: :string, options: {}) } }
            let(:fake_formatted_fields) { { "title" => {"type" => "string"}}}

            subject { described_class.new(presenter) }

            before do
              stub(presenter).nodoc?                           { nodoc }
              stub(presenter).target_class                     { presented_class }
              stub(presenter).description                      { lorem }
              stub(presenter).title                            { title }
              stub(presenter).contextual_documentation(:title) { title }
            end

            describe '#call' do
              before do
                stub(presenter).format_title!      { title }
                stub(presenter).format_fields!     { fake_formatted_fields }
                stub(presenter).valid_fields       { valid_fields }
                stub(presenter).valid_associations { {} }
              end

              context 'when nodoc' do
                let(:nodoc) {true}

                before do
                  any_instance_of(described_class) do |instance|
                    dont_allow(instance).format_title!
                    dont_allow(instance).format_description!
                    dont_allow(instance).format_type!
                    dont_allow(instance).format_fields!
                  end
                end

                it 'returns an empty output' do
                  expect(subject.call).to be {}
                end
              end

              context 'when not nodoc' do
                let(:nodoc) {false}

                before do
                  any_instance_of(described_class) do |instance|
                    mock.proxy(instance).format_title!
                    mock.proxy(instance).format_description!
                    mock.proxy(instance).format_type!
                    mock.proxy(instance).format_fields!
                  end
                end

                it 'formats data' do
                  expect(subject.call).to_not be_empty
                end

                it 'top level key in the output is set to the presented class' do
                  subject.call

                  expect(subject.output.keys).to eq([presented_class])
                  expect(subject.output[presented_class].keys).to eq(%w(title description type properties))
                  expect(subject.output[presented_class]['title']).to eq(title)
                  expect(subject.output[presented_class]['description']).to eq("#{lorem}.")
                  expect(subject.output[presented_class]['type']).to eq('object')
                  expect(subject.output[presented_class]['properties']).to eq(fake_formatted_fields)
                end
              end
            end

            describe '#format_title!' do
              before do
                stub(presenter).valid_fields { valid_fields }
              end

              context 'when the presenter has a title' do
                let(:title) { 'Sprockets are cool, I think' }

                it 'returns the title' do
                  subject.send(:format_title!)

                  expect(subject.definition).to have_key(:title)
                  expect(subject.definition[:title]).to eq title
                end
              end

              context 'when the presenter does not have a title' do
                let(:title) { nil }

                it 'returns formatted key' do
                  subject.send(:format_title!)

                  expect(subject.definition).to have_key(:title)
                  expect(subject.definition[:title]).to eq presented_class
                end
              end
            end

            describe '#format_description' do
              context 'when the presenter has a description' do
                let(:lorem) {'                  way over here   '}

                it 'returns the string-ized stripped description' do
                  subject.send(:format_description!)

                  expect(subject.definition).to have_key(:description)
                  expect(subject.definition[:description]).to eq 'Way over here.'
                end
              end

              context 'when the presenter does not have a description' do
                let(:lorem) { nil }

                it 'returns an empy string' do
                  subject.send(:format_description!)

                  expect(subject.definition).to have_key(:description)
                  expect(subject.definition[:description]).to eq ''
                end
              end
            end

            describe '#format_fields!' do
              let(:presenter_class) do
                Class.new(Brainstem::Presenter) do
                  presents Workspace
                end
              end
              let(:presenter)    { Presenter.new(Object.new, const: presenter_class, target_class: 'Workspace') }
              let(:conditionals) { {} }

              before do
                stub(presenter).conditionals { conditionals }
              end

              context 'with associations present' do
                context 'when association type is belongs_to or has_one' do
                  before do
                    presenter_class.associations do
                      association :task, Task,
                        foreign_key: :task_id,
                        type: :belongs_to,
                        info: "Assign people to your task"

                      association :user, User,
                        foreign_key: :user_id,
                        type: :has_one,
                        info: "People are users"
                    end
                  end

                  it 'outputs the foreign key in single formatted id' do
                    subject.send(:format_fields!)

                    expect(subject.definition).to have_key :properties
                    expect(subject.definition[:properties]).to eq({
                      'task_id' => { 'type' => 'integer', 'format' => 'int32', 'description' => 'Assign people to your task' },
                      'user_id' => { 'type' => 'integer', 'format' => 'int32', 'description' => 'People are users' }
                    })
                  end
                end

                context 'when association type is has_many' do
                  before do
                    presenter_class.associations do
                      association :task, Task,
                        foreign_key: :task_id,
                        type: :has_many,
                        info: "Assign people to your task"
                    end
                  end

                  it 'outputs the foreign key in plural formatted id' do
                    subject.send(:format_fields!)

                    expect(subject.definition).to have_key :properties
                    expect(subject.definition[:properties]).to eq({
                      'task_ids' => {
                        'type' => 'array',
                        'description' => 'Assign people to your task',
                        'items' => {
                          'type' => 'integer',
                          'format' => 'int32'
                        },
                      },
                    })
                  end
                end

                context 'when association is polymorphic' do
                  before do
                    presenter_class.associations do
                      association :task, :polymorphic,
                        polymorphic_classes: [User, Task],
                        info: "Users and tasks"
                    end
                  end

                  it 'outputs an object that contains an id and key' do
                    subject.send(:format_fields!)

                    expect(subject.definition).to have_key :properties
                    expect(subject.definition[:properties]).to eq({
                      'task_ref' => {
                        'type' => 'object',
                        'description' => 'Users and tasks',
                        'properties' => {
                          'id' => {
                            'type' => 'string'
                          },
                          'key' => {
                            'type' => 'string'
                          }
                        }
                      }
                    })
                  end
                end
              end

              context 'with fields present' do
                describe 'branch node' do
                  context 'with single branch' do
                    before do
                      presenter_class.fields do
                        fields :sprockets do
                          field :sprocket_name, :string, via: :name, info: 'Whatever.'
                        end
                      end
                    end

                    it 'outputs the name of sub-branch as a property of the parent' do
                      subject.send(:format_fields!)

                      expect(subject.definition).to have_key :properties
                      expect(subject.definition[:properties]).to eq({
                        'sprockets' => {
                          'type' => 'object',
                          'properties' => {

                            'sprocket_name' => { 'type' => 'string', 'description' => 'Whatever.' }
                          }
                        }
                      })
                    end
                  end

                  context 'with sub-branch of type hash' do
                    before do
                      presenter_class.fields do
                        fields :sprockets do
                          fields :sub_sprocket do
                            field :sprocket_name, :string, via: :name, info: 'Whatever.'
                          end
                        end
                      end
                    end

                    it 'outputs the name of sub-branches as a properties of the its parent' do
                      subject.send(:format_fields!)

                      expect(subject.definition).to have_key :properties
                      expect(subject.definition[:properties]).to eq({
                        'sprockets' => {
                          'type' => 'object',
                          'properties' => {

                            'sub_sprocket' => {
                              'type' => 'object',
                              'properties' => {

                                'sprocket_name' => { 'type' => 'string', 'description' => 'Whatever.' }
                              }
                            }
                          }
                        }
                      })
                    end
                  end

                  context 'with sub branch of type array' do
                    xcontext 'when type of list items is an array'

                    context 'when type of list items is a hash' do
                      before do
                        presenter_class.fields do
                          fields :sprockets, :array, item_type: 'hash', info: 'parent' do
                            field :sprocket_name, :string, via: :name, info: 'Whatever.'
                          end
                        end
                      end

                      it 'outputs the name of sub-branches as a properties of the its parent' do
                        subject.send(:format_fields!)

                        expect(subject.definition).to have_key :properties
                        expect(subject.definition[:properties]).to eq({
                          'sprockets' => {
                            'type' => 'array',
                            'description' => 'Parent.',
                            'items' => {
                              'type' => 'object',
                              'properties' => {

                                'sprocket_name' => { 'type' => 'string', 'description' => 'Whatever.' }
                              }
                            }
                          }
                        })
                      end
                    end
                  end
                end

                describe 'leaf node' do
                  context 'if it is not conditional' do
                    before do
                      presenter_class.fields do
                        field :sprocket_name, :string, info: 'whatever'
                        field :sprocket_size, :integer
                      end
                    end

                    it 'outputs each field as a list item' do
                      subject.send(:format_fields!)

                      expect(subject.definition).to have_key :properties
                      expect(subject.definition[:properties]).to eq({
                        'sprocket_name' => { 'type' => 'string', 'description' => 'Whatever.' },
                        'sprocket_size' => { 'type' => 'integer', 'format' => 'int32' }
                      })
                    end

                    describe 'optional' do
                      let(:formatted_description) { subject.definition[:properties]['sprocket_name']['description'] }

                      context 'when true' do
                        before do
                          presenter_class.fields do
                            field :sprocket_name, :string, info: 'Whatever.', optional: true
                            field :sprocket_size, :integer
                          end
                        end

                        it 'says so' do
                          subject.send(:format_fields!)

                          expect(subject.definition).to have_key :properties
                          expect(formatted_description).to include 'Only returned when requested'
                        end
                      end

                      context 'when false' do
                        before do
                          presenter_class.fields do
                            field :sprocket_name, :string, info: 'Whatever.', optional: false
                            field :sprocket_size, :integer
                          end
                        end

                        it 'says nothing' do
                          subject.send(:format_fields!)

                          expect(subject.definition).to have_key :properties
                          expect(formatted_description).to_not include 'Only returned when requested'
                        end
                      end
                    end

                    describe 'description' do
                      context 'when present' do
                        before do
                          presenter_class.fields do
                            field :sprocket_name, :string, info: 'Whatever.'
                            field :sprocket_size, :integer
                          end
                        end

                        it 'outputs the description' do
                          subject.send(:format_fields!)

                          expect(subject.definition).to have_key :properties
                          expect(subject.definition[:properties]['sprocket_name']['description']).to eq('Whatever.')
                        end
                      end

                      context 'when absent' do
                        before do
                          presenter_class.fields do
                            field :sprocket_name, :string
                            field :sprocket_size, :integer
                          end
                        end

                        it 'does not include the description' do
                          subject.send(:format_fields!)

                          expect(subject.definition).to have_key :properties
                          expect(subject.definition[:properties]['sprocket_name']).to_not have_key('description')
                        end
                      end
                    end
                  end

                  context 'if it is conditional' do
                    let(:formatted_description) {subject.definition[:properties]['sprocket_name']['description']}

                    before do
                      presenter_class.fields do
                        field :sprocket_name, :string, info: 'whatever', if: [:it_is_a_friday]
                      end
                    end

                    context 'if nodoc' do
                      let(:conditionals) {
                        {
                          :it_is_a_friday => OpenStruct.new(
                            description: nil,
                            name:        :it_is_a_friday,
                            type:        :request,
                            options:     { nodoc: true }
                          )
                        }
                      }

                      it 'does not include the conditional' do
                        subject.send(:format_fields!)

                        expect(formatted_description).not_to include 'Visible when'
                      end
                    end

                    context 'if not nodoc' do
                      context 'if the conditional has a description' do
                        let(:conditionals) {
                          {
                            :it_is_a_friday => OpenStruct.new(
                              description: 'It is a friday',
                              name:        :it_is_a_friday,
                              type:        :request,
                              options:     {},
                            )
                          }
                        }

                        it 'includes the conditional' do
                          subject.send(:format_fields!)

                          expect(formatted_description).to include 'Visible when it is a friday.'
                        end
                      end

                      context 'if the condition doesn\'t have a description' do
                        let(:conditionals) {
                          {
                            :it_is_a_friday => OpenStruct.new(
                              description: nil,
                              name:        :it_is_a_friday,
                              type:        :request,
                              options:     {},
                            )
                          }
                        }

                        it 'does not include the conditional' do
                          subject.send(:format_fields!)

                          expect(formatted_description).not_to include 'Visible when'
                        end
                      end
                    end
                  end

                  context 'when invalid type specified' do
                    before do
                      presenter_class.fields do
                        field :sprocket_name, :invalid
                      end
                    end

                    it 'raises an error' do
                      expect { subject.send(:format_fields!) }.to raise_error(StandardError)
                    end
                  end
                end
              end

              context 'with no fields' do
                let(:valid_fields) {{}}

                it 'outputs that no fields were listed' do
                  subject.send(:format_fields!)

                  expect(subject.definition[:properties]).to be_nil
                end
              end
            end
          end
        end
      end
    end
  end
end
