require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/field_definitions/endpoint_param_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module FieldDefinitions
            describe EndpointParamFormatter do
              describe '#format' do
                let(:endpoint) { OpenStruct.new(controller_name: 'Test', action: 'create') }
                let(:field_name) { 'sprocket' }
                let(:configuration_tree) { field_configuration_tree.with_indifferent_access }

                subject { described_class.new(endpoint, field_name, configuration_tree).format }

                context 'when formatting nested field' do
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
                        support_email: {
                          _config: {
                            required: true,
                            type: 'string',
                            info: 'contact support',
                            nodoc: false
                          },
                        },
                        version: {
                          _config: {
                            type: 'string',
                            info: 'the version of the widget',
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
                              required: true,
                              type: 'array',
                              item_type: 'boolean',
                              nodoc: false
                            },
                          },
                          can_delete: {
                            _config: {
                              type: 'boolean',
                              nodoc: false
                            },
                          },
                          can_rename: {
                            _config: {
                              type: 'boolean',
                              info: 'can rename the widget',
                              nodoc: false
                            },
                          },
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
                            'required' => ['widget_name', 'support_email'],
                            'properties' => {
                              'widget_name' => {
                                'type' => 'string',
                                'description' => 'The name of the widget.',
                              },
                              'support_email' => {
                                'type' => 'string',
                                'description' => 'Contact support.',
                              },
                              'version' => {
                                'type' => 'string',
                                'description' => 'The version of the widget.',
                              },
                              'widget_permissions' => {
                                'type' => 'array',
                                'description' => 'The permissions of the widget.',
                                'items' => {
                                  'type' => 'object',
                                  'required' => ['can_edit'],
                                  'properties' => {
                                    'can_edit' => {
                                      'type' => 'array',
                                      'items' => {
                                        'type' => 'boolean',
                                      }
                                    },
                                    'can_delete' => {
                                      'type' => 'boolean',
                                    },
                                    'can_rename' => {
                                      'type' => 'boolean',
                                      'description' => 'Can rename the widget.',
                                    },
                                  },
                                },
                              },
                            },
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
                        'required' => ['widget_name'],
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
                end
              end
            end
          end
        end
      end
    end
  end
end
