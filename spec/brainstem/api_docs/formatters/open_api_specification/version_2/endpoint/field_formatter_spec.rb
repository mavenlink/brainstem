require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/endpoint/field_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module Endpoint
            describe FieldFormatter do
              describe '#format' do
                let(:simple_configuration_tree) do
                  {
                    _config: {
                      type: 'string',
                      info: 'The name of the sprocket'
                    }
                  }
                end

                it 'formats a simple configuration tree with no children' do
                  expected_tree = {
                    'type' => simple_configuration_tree[:_config][:type],
                    'description' => simple_configuration_tree[:_config][:info] + '.',
                  }

                  expect(described_class.new(simple_configuration_tree).format).to eq(expected_tree)
                end

                let(:complicated_configuration_tree) do
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
                        info: 'The name of the widget.',
                        nodoc: false
                      },
                    },
                    widget_permissions: {
                      _config: {
                        type: 'array',
                        item_type: 'hash',
                        info: 'The permissions of the widget.',
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
                  widget_name_config = complicated_configuration_tree[:widget_name][:_config]
                  widget_permissions = complicated_configuration_tree[:widget_permissions]
                  widget_permissions_config = widget_permissions[:_config]
                  can_edit_config = widget_permissions[:can_edit][:_config]

                  expected_tree = {
                    'type' => 'array',
                    'items' => {
                      'type' => 'array',
                      'items' => {
                        'type' => 'object',
                        'properties' => {
                          'widget_name' => {
                            'type' => widget_name_config[:type],
                            'description' => widget_name_config[:info]
                          },
                          'widget_permissions' => {
                            'type' => widget_permissions_config[:type],
                            'description' => widget_permissions_config[:info],
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
                                        'type' => can_edit_config[:item_type]
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
                  }

                  expect(described_class.new(complicated_configuration_tree).format).to eq(expected_tree)
                end
              end


              context 'modifying options argument' do
                context 'when include_required is true' do
                  let(:simple_configuration_tree_required) do
                    {
                      _config: {
                        type: 'array',
                        info: 'Attributes for the assignees.'
                      },
                      id: {
                        _config: {
                          required: true,
                          type: 'integer',
                          info: 'ID of the assignee.'
                        }
                      },
                      active: {
                        _config: {
                          type: 'boolean',
                          info: 'Activates the assignment.'
                        }
                      },
                      friends: {
                        _config: {
                          required: true,
                          type: 'hash',
                          info: 'The best friends.'
                        },
                        frodo: {
                          _config: {
                            required: true,
                            type: 'password',
                            info: 'One ring to bind them.'
                          }
                        }
                      }
                    }
                  end

                  it 'adds required key to objects where direct children are required' do
                    top_config = simple_configuration_tree_required[:_config]
                    id_config = simple_configuration_tree_required[:id][:_config]
                    active_config = simple_configuration_tree_required[:active][:_config]
                    friends = simple_configuration_tree_required[:friends]
                    friends_config = friends[:_config]
                    frodo_config = friends[:frodo][:_config]

                    expected_tree = {
                      'type' => top_config[:type],
                      'description' => top_config[:info],
                      'items' => {
                        'type' => 'object',
                        'properties' => {
                          'id' => {
                            'type' => id_config[:type],
                            'format' => 'int32',
                            'description' => id_config[:info]
                          },
                          'active' => {
                            'type' => active_config[:type],
                            'description' => active_config[:info]
                          },
                          'friends' => {
                            'type' => 'object',
                            'description' => friends_config[:info],
                            'properties' => {
                              'frodo' => {
                                'type' => 'string',
                                'format' => frodo_config[:type],
                                'description' => frodo_config[:info]
                              }
                            },
                            'required' => [:frodo]
                          }
                        },
                        'required' => [:id, :friends]
                      }
                    }

                    expect(
                      described_class.new(simple_configuration_tree_required, include_required: true).format
                    ).to eq(expected_tree)
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
