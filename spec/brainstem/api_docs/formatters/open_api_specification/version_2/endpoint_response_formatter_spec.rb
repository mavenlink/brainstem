require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/endpoint_response_formatter'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          describe EndpointResponseFormatter do
            let(:controller)    { Object.new }
            let(:presenter)     { Object.new }
            let(:atlas)         { Object.new }
            let(:action)        { 'show' }
            let(:http_methods)  { %w(GET) }
            let(:endpoint)      {
              Endpoint.new(
                atlas,
                endpoint_args
              )
            }
            let(:endpoint_args) { {} }

            subject { described_class.new(endpoint) }

            before do
              stub(presenter).contextual_documentation(:title) { 'Widget' }
              stub(endpoint).presenter { presenter }
              stub(endpoint).action { action }
              stub(endpoint).custom_response_configuration_tree { {} }
              stub(endpoint).http_methods { http_methods }
            end

            describe '#call' do
              context 'when delete request' do
                let(:http_methods) { %w(DELETE) }

                it 'formats the delete response and error response' do
                  any_instance_of(described_class) do |instance|
                    mock(instance).format_delete_response!
                    mock(instance).format_error_responses!

                    dont_allow(instance).format_schema_response!
                  end

                  subject.call
                end
              end

              context 'when request is not delete' do
                let(:http_methods) { %w(GET) }

                it 'formats the schema response and error response' do
                  any_instance_of(described_class) do |instance|
                    mock(instance).format_schema_response!
                    mock(instance).format_error_responses!

                    dont_allow(instance).format_delete_response!
                  end

                  subject.call
                end
              end

            end

            describe '#formatting' do
              describe '#success_response_description' do
                subject { described_class.new(endpoint).send(:success_response_description) }

                context 'when `GET` request' do
                  let(:http_methods) { %w(GET) }

                  it { is_expected.to eq('A list of Widgets have been retrieved') }
                end

                context 'when `POST` request' do
                  let(:http_methods) { %w(POST) }

                  it { is_expected.to eq('Widget has been created') }
                end

                context 'when `PUT` request' do
                  let(:http_methods) { %w(PUT) }

                  it { is_expected.to eq('Widget has been updated') }
                end

                context 'when `PATCH` request' do
                  let(:http_methods) { %w(PATCH) }

                  it { is_expected.to eq('Widget has been updated') }
                end

                context 'when `DELETE` request' do
                  let(:http_methods) { %w(DELETE) }

                  it { is_expected.to eq('Widget has been deleted') }
                end
              end

              describe '#format_delete_response!' do
                let(:http_methods) { %w(DELETE) }

                it 'returns the structure response for a destroy action' do
                  subject.send(:format_delete_response!)

                  expect(subject.output).to eq('204' => { 'description' => 'Widget has been deleted' })
                end
              end

              describe '#format_schema_response!' do
                before do
                  stub(presenter).brainstem_keys { ['widgets'] }
                  stub(presenter).target_class { 'Widget' }
                end

                it 'returns the structured response for an endpoint' do
                  subject.send(:format_schema_response!)

                  expect(subject.output).to eq('200' => {
                    'description' => 'A list of Widgets have been retrieved',
                    'schema' => {
                      'type' => 'object',
                      'properties' => {
                        'count' => { 'type' => 'integer', 'format' => 'int32' },
                        'meta' => {
                          'type' => 'object',
                          'properties' => {
                            'count'       => { 'type' => 'integer', 'format' => 'int32' },
                            'page_count'  => { 'type' => 'integer', 'format' => 'int32' },
                            'page_number' => { 'type' => 'integer', 'format' => 'int32' },
                            'page_size'   => { 'type' => 'integer', 'format' => 'int32' },
                          }
                        },
                        'results' => {
                          'type' => 'array',
                          'items' => {
                            'type' => 'object',
                            'properties' => {
                              'key' => { 'type' => 'string' },
                              'id' =>  { 'type' => 'string' }
                            }
                          }
                        },
                        'widgets' => {
                          'type' => 'object',
                          'additionalProperties' => {
                            '$ref' => '#/definitions/Widget'
                          }
                        }
                      }
                    }
                  })
                end
              end

              describe '#format_error_responses!' do
                it 'returns the structured errors responses for an endpoint' do
                  subject.send(:format_error_responses!)

                  expect(subject.output).to eq(
                    '400' => { 'description' => 'Bad Request',            'schema' => { '$ref' => '#/definitions/Errors' }  },
                    '401' => { 'description' => 'Unauthorized request',   'schema' => { '$ref' => '#/definitions/Errors' }  },
                    '403' => { 'description' => 'Forbidden request',      'schema' => { '$ref' => '#/definitions/Errors' }  },
                    '404' => { 'description' => 'Page Not Found',         'schema' => { '$ref' => '#/definitions/Errors' }  },
                    '503' => { 'description' => 'Service is unavailable', 'schema' => { '$ref' => '#/definitions/Errors' }  }
                  )
                end
              end

              describe '#format_custom_response!' do
                context 'when the response is a hash' do
                  before do
                    stub(endpoint).custom_response_configuration_tree {
                      {
                        '_config' => {
                          'type' => 'hash',
                        },
                        'widget_name' => {
                          '_config' => {
                            'type' => 'string',
                            'info' => 'the name of the widget',
                            'nodoc' => false
                          },
                        },
                        'widget_permission' => {
                          '_config' => {
                            'type' => 'hash',
                            'info' => 'the permissions of the widget',
                            'nodoc' => false
                          },
                          'can_edit' => {
                            '_config' => {
                              'type' => 'boolean',
                              'info' => 'can edit the widget',
                              'nodoc' => false
                            },
                          }
                        },
                      }.with_indifferent_access
                    }
                  end

                  it 'returns the response structure' do
                    subject.send(:format_custom_response!)

                    expect(subject.output).to eq('200' => {
                      'description' => 'A list of Widgets have been retrieved',
                      'schema' => {
                        'type' => 'object',
                        'properties' => {
                          'widget_name' => {
                            'type' => 'string',
                            'description' => 'the name of the widget'
                          },
                          'widget_permission' => {
                            'type' => 'object',
                            'description' => 'the permissions of the widget',
                            'properties' => {
                              'can_edit' => {
                                'type' => 'boolean',
                                'description' => 'can edit the widget'
                              }
                            }
                          }
                        }
                      }
                    })
                  end
                end

                context 'when the response is an array' do
                  before do
                    stub(endpoint).custom_response_configuration_tree {
                      {
                        '_config' => {
                          'type' => 'array',
                          'item_type' => 'hash',
                        },
                        'widget_name' => {
                          '_config' => {
                            'type' => 'string',
                            'info' => 'the name of the widget',
                            'nodoc' => false
                          },
                        },
                        'widget_permissions' => {
                          '_config' => {
                            'type' => 'array',
                            'item_type' => 'hash',
                            'info' => 'the permissions of the widget',
                            'nodoc' => false
                          },
                          'can_edit' => {
                            '_config' => {
                              'type' => 'boolean',
                              'info' => 'can edit the widget',
                              'nodoc' => false
                            },
                          }
                        },
                      }.with_indifferent_access
                    }
                  end

                  it 'returns the response structure' do
                    subject.send(:format_custom_response!)

                    expect(subject.output).to eq('200' => {
                      'description' => 'A list of Widgets have been retrieved',
                      'schema' => {
                        'type' => 'array',
                        'items' => {
                          'type' => 'object',
                          'properties' => {
                            'widget_name' => {
                              'type' => 'string',
                              'description' => 'the name of the widget'
                            },
                            'widget_permissions' => {
                              'type' => 'array',
                              'description' => 'the permissions of the widget',
                              'items' => {
                                'type' => 'object',
                                'properties' => {
                                  'can_edit' => {
                                    'type' => 'boolean',
                                    'description' => 'can edit the widget'
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    })
                  end
                end

                context 'when the response is not a hash or array' do
                  before do
                    stub(endpoint).custom_response_configuration_tree {
                      {
                        '_config' => {
                          'type' => 'boolean',
                          'info' => 'whether the widget exists',
                          'nodoc' => false
                        },
                      }.with_indifferent_access
                    }
                  end

                  it 'returns the response structure' do
                    subject.send(:format_custom_response!)

                    expect(subject.output).to eq('200' => {
                      'description' => 'A list of Widgets have been retrieved',
                      'schema' => {
                        'type' => 'boolean',
                        'description' => 'whether the widget exists'
                      }
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
