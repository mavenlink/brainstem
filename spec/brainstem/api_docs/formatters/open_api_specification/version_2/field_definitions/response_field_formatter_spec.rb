require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/field_definitions/response_field_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module FieldDefinitions
            describe ResponseFieldFormatter do
              describe '#format' do
                let(:endpoint) { OpenStruct.new(controller_name: 'Test', action: 'create') }
                let(:field_name) { 'sprocket' }
                let(:configuration_tree) { field_configuration_tree.with_indifferent_access }

                subject { described_class.new(endpoint, field_name, configuration_tree).format }

                context 'when formatting non-nested field' do
                  let(:field_configuration_tree) do
                    {
                      _config: {
                        type: 'string',
                        info: 'The name of the sprocket'
                      }
                    }
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
                    let(:field_configuration_tree) do
                      {
                        _config: {
                          type: 'array',
                          item_type: 'long',
                        },
                      }
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq(
                        'type' => 'array',
                        'items' => {
                          'type' => 'integer', 'format' => 'int64'
                        }
                      )
                    end
                  end

                  context 'when formatting a nested array field with non nested data type' do
                    let(:field_configuration_tree) do
                      {
                        _config: {
                          type: 'array',
                          nested_levels: 3,
                          item_type: 'decimal',
                        },
                      }
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq(
                        'type' => 'array',
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
                    let(:field_configuration_tree) do
                      {
                        _config: {
                          type: 'array',
                          nested_levels: 2,
                          item_type: 'hash',
                        },
                        widget_name: {
                          _config: {
                            required: true,
                            type: 'string',
                            info: 'the name of the widget',
                            nodoc: false
                          },
                        },
                        widget_permissions: {
                          _config: {
                            type: 'array',
                            item_type: 'hash',
                            info: 'the permissions of the widget',
                            nodoc: false
                          },
                          can_edit: {
                            _config: {
                              type: 'array',
                              nested_levels: 3,
                              item_type: 'boolean',
                              nodoc: false
                            },
                          }
                        },
                      }
                    end

                    it 'formats a complicated tree with arrays and hashes as children' do
                      expect(subject).to eq(
                        'type' => 'array',
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
                    let(:field_configuration_tree) do
                      {
                        _config: {
                          type: 'hash',
                          info: 'Details about the widget',
                        },
                        widget_name: {
                          _config: {
                            required: true,
                            type: 'string',
                            info: 'the name of the widget',
                            nodoc: false
                          },
                        },
                        widget_permissions: {
                          _config: {
                            type: 'array',
                            item_type: 'string',
                            info: 'the permissions of the widget',
                            nodoc: false
                          },
                        },
                      }
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
                              'type' => 'string',
                            }
                          }
                        }
                      )
                    end
                  end

                  context 'when formatting a multi nested hash field' do
                    let(:field_configuration_tree) do
                      {
                        _config: {
                          type: 'hash',
                          info: 'Details about the widget',
                        },
                        widget_name: {
                          _config: {
                            required: true,
                            type: 'string',
                            info: 'the name of the widget',
                            nodoc: false
                          },
                        },
                        widget_permissions: {
                          _config: {
                            type: 'hash',
                            info: 'the permissions of the widget',
                            nodoc: false
                          },
                          can_edit: {
                            _config: {
                              type: 'boolean',
                              info: 'can edit the widget',
                              nodoc: false
                            }
                          }
                        },
                      }
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

                context 'when the field is an enum' do
                  let(:field_configuration_tree) do
                    {
                      _config: {
                        type: 'string',
                        info: 'The type of the sprocket.',
                        enum: %w(Mesh Chain Wheel)
                      }
                    }
                  end

                  it 'is reflected in the oas schema' do
                    expect(subject).to eq(
                      'type' => 'string',
                      'description' => 'The type of the sprocket.',
                      'enum' => %w(Mesh Chain Wheel)
                    )
                  end
                end

                context 'dynamic keys' do
                  context 'when formatting a hash field' do
                    let(:field_configuration_tree) do
                      {
                        _config: {
                          type: 'hash',
                          info: 'Dynamic keys hash.',
                        },
                        _dynamic_key: {
                          _config: {
                            nodoc: false,
                            type: 'hash',
                            dynamic_key: true,
                            info: 'a dynamic description.'
                          },
                          blah: {
                            _config: {
                              nodoc: false,
                              type: 'string',
                            },
                          },
                        },
                      }
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq({
                        'type' => 'object',
                        'description' => 'Dynamic keys hash.',
                        'additionalProperties' => {
                          'type' => 'object',
                          'description' => 'A dynamic description.',
                          'properties' => {
                            'blah' => {
                              'type' => 'string',
                            },
                          },
                        },
                      })
                    end
                  end

                  context 'when formatting a nested hash field' do
                    let(:field_configuration_tree) do
                      {
                        _config: {
                          type: 'hash',
                          info: 'Dynamic keys hash.',
                        },
                        non_dynamic_key: {
                          _config: {
                            nodoc: false,
                            type: 'hash',
                            info: 'A non-dynamic description.'
                          },
                          non_dynamic_property: {
                            _config: {
                              nodoc: false,
                              type: 'string',
                            },
                          },
                        },
                        _dynamic_key: {
                          _config: {
                            nodoc: false,
                            type: 'hash',
                            dynamic_key: true,
                            info: 'A dynamic description.'
                          },
                          dynamic_property1: {
                            _config: {
                              nodoc: false,
                              type: 'string',
                            },
                          },
                          _dynamic_key: {
                            _config: {
                              nodoc: false,
                              type: 'hash',
                              dynamic_key: true,
                              info: 'A 2nd dynamic description.'
                            },
                            _dynamic_key: {
                              _config: {
                                nodoc: false,
                                type: 'string',
                                dynamic_key: true,
                                info: 'A dynamic string.'
                              },
                            },
                            dynamic_property2: {
                              _config: {
                                nodoc: false,
                                type: 'string',
                              },
                            },
                          },
                        },
                      }
                    end

                    it 'returns the formatted field schema' do
                      expect(subject).to eq({
                        'type' => 'object',
                        'description' => 'Dynamic keys hash.',
                        'properties' => {
                          'non_dynamic_key' => {
                            'type' => 'object',
                            'description' => 'A non-dynamic description.',
                            'properties' => {
                              'non_dynamic_property' => {
                                'type' => 'string',
                              }
                            }
                          },
                        },
                        'additionalProperties' => {
                          'type' => 'object',
                          'description' => 'A dynamic description.',
                          'properties' => {
                            'dynamic_property1' => {
                              'type' => 'string',
                            },
                          },
                          'additionalProperties' => {
                            'type' => 'object',
                            'description' => 'A 2nd dynamic description.',
                            'properties' => {
                              'dynamic_property2' => {
                                'type' => 'string',
                              },
                            },
                            'additionalProperties' => {
                              'type' => 'string',
                              'description' => 'A dynamic string.',
                            },
                          },
                        },
                      })
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
