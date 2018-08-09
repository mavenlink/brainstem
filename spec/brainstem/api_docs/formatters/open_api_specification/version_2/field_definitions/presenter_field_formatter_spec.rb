require 'spec_helper'
require 'brainstem/api_docs/presenter'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/field_definitions/presenter_field_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module FieldDefinitions
            describe PresenterFieldFormatter do
              describe '#format' do
                let(:presenter_class) do
                  Class.new(Brainstem::Presenter) do
                    presents Workspace
                  end
                end
                let(:presenter)    { Presenter.new(Object.new, const: presenter_class, target_class: 'Workspace') }
                let(:conditionals) { {} }
                let(:field)        { presenter.valid_fields.values.first }
                

                subject { described_class.new(presenter, field).format }

                before do
                  stub(presenter).conditionals { conditionals }
                end

                context 'when formatting non-nested field' do
                  before do
                    presenter_class.fields do
                      field :sprocket_name, :string, via: :name, info: 'The name of the sprocket'
                    end
                  end

                  it 'returns the formatted field schema' do
                    expect(subject).to eq(
                      'type' => 'string',
                      'description' => 'The name of the sprocket.',
                    )
                  end
                end

                context 'when formatting nested field' do
                  context 'when formatting an array field' do
                    before do
                      presenter_class.fields do
                        field :sprocket_names, :array, info: 'All the names for the sprocket'
                      end
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq(
                        'type' => 'array',
                        'description' => 'All the names for the sprocket.',
                        'items' => {
                          'type' => 'string',
                        }
                      )
                    end
                  end

                  context 'when formatting a nested array field with non nested data type' do
                    before do
                      presenter_class.fields do
                        field :sprocket_usages, :array,
                          item_type: :decimal,
                          nested_levels: 3,
                          info: 'All the names for the sprocket'
                      end
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq(
                        'type' => 'array',
                        'description' => 'All the names for the sprocket.',
                        'items' => {
                          'type' => 'array',
                          'items' => {
                            'type' => 'array',
                            'items' => {
                              'type' => 'number',
                              'format' => 'float'
                            }
                          }
                        }
                      )
                    end
                  end

                  context 'when formatting a nested array field with objects' do
                    before do
                      presenter_class.fields do
                        fields :sprockets, :array, nested_levels: 2, info: 'I am a sprocket' do
                          field :widget_name, :string,
                            info: 'the name of the widget'

                          fields :widget_permissions, :array, info: 'the permissions of the widget' do
                            field :can_edit, :array,
                              nested_levels: 3,
                              item_type: 'boolean',
                              info: 'the ethos of the widget'
                          end
                        end
                      end
                    end

                    it 'formats a complicated tree with arrays and hashes as children' do
                      expect(subject).to eq(
                        'type' => 'array',
                        'description' => 'I am a sprocket.',
                        'items' => {
                          'type' => 'array',
                          'items' => {
                            'type' => 'object',
                            'properties' => {
                              'widget_name' => {
                                'type' => 'string',
                                'description' => 'The name of the widget.',
                              },
                              'widget_permissions' => {
                                'type' => 'array',
                                'description' => 'The permissions of the widget.',
                                'items' => {
                                  'type' => 'object',
                                  'properties' => {
                                    'can_edit' => {
                                      'type' => 'array',
                                      'description' => 'The ethos of the widget.',
                                      'items' => {
                                        'type' => 'array',
                                        'items' => {
                                          'type' => 'array',
                                          'items' => {
                                            'type' => 'boolean'
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      )
                    end
                  end

                  context 'when formatting a hash field' do
                    before do
                      presenter_class.fields do
                        fields :sprockets, :hash, info: 'Details about the widget' do
                          field :widget_name, :string,
                            info: 'the name of the widget'

                          fields :widget_permissions, :array, info: 'the permissions of the widget' do
                            field :can_edit, :boolean,
                              info: 'can edit the widget'
                          end
                        end
                      end
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq(
                        'type' => 'object',
                        'description' => 'Details about the widget.',
                        'properties' => {
                          'widget_name' => {
                            'type' => 'string',
                            'description' => 'The name of the widget.',
                          },
                          'widget_permissions' => {
                            'type' => 'array',
                            'description' => 'The permissions of the widget.',
                            'items' => {
                              'type' => 'object',
                              'properties' => {
                                'can_edit' => {
                                  'type' => 'boolean',
                                  'description' => 'Can edit the widget.'
                                }
                              }
                            }
                          }
                        }
                      )
                    end
                  end

                  context 'when formatting a multi nested hash field' do
                    before do
                      presenter_class.fields do
                        fields :sprockets do
                          field :widget_name, :string,
                            info: 'the name of the widget'

                          fields :widget_permissions, :hash, info: 'the permissions of the widget' do
                            field :can_edit, :boolean,
                              info: 'can edit the widget'
                          end
                        end
                      end
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq(
                        'type' => 'object',
                        'properties' => {
                          'widget_name' => {
                            'type' => 'string',
                            'description' => 'The name of the widget.',
                          },
                          'widget_permissions' => {
                            'type' => 'object',
                            'description' => 'The permissions of the widget.',
                            'properties' => {
                              'can_edit' => {
                                'type' => 'boolean',
                                'description' => 'Can edit the widget.',
                              }
                            }
                          }
                        }
                      )
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
