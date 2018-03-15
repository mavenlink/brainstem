require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_params_formatter'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        describe EndpointParamsFormatter do
          let(:controller)    { Object.new }
          let(:presenter)     { Object.new }
          let(:atlas)         { Object.new }
          let(:action)        { 'show' }
          let(:endpoint)      {
            Endpoint.new(
              atlas,
              {
                http_methods: %w(get post),
                path:         '/widgets(.:format)'
              }.merge(endpoint_args)
            )
          }
          let(:endpoint_args) { {} }
          let(:nodoc)         { false }

          subject { described_class.new(endpoint) }

          before do
            stub(endpoint).presenter { presenter }
            stub(endpoint).action { action }
          end

          describe '#call' do
            context 'when action is index' do
              let(:action) { 'index' }

              it 'formats path, shared, query and body params for the endpoint' do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_path_params!
                  mock(instance).format_optional_params!
                  mock(instance).format_query_params!
                  mock(instance).format_body_params!
                  mock(instance).format_pagination_params!
                  mock(instance).format_search_param!
                  mock(instance).format_only_param!
                  mock(instance).format_sort_order_params!
                  mock(instance).format_filter_params!
                end

                subject.call
              end
            end

            context 'when action is show' do
              let(:action) { 'show' }

              it 'formats path, optional, query and body params for the endpoint' do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_path_params!
                  mock(instance).format_optional_params!
                  mock(instance).format_query_params!
                  mock(instance).format_body_params!

                  dont_allow(instance).format_pagination_params!
                  dont_allow(instance).format_search_param!
                  dont_allow(instance).format_only_param!
                  dont_allow(instance).format_sort_order_params!
                  dont_allow(instance).format_filter_params!
                end

                subject.call
              end
            end

            context 'when action is not index' do
              let(:action) { 'update' }

              it 'formats path, query and body param for the endpoint' do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_path_params!
                  mock(instance).format_query_params!
                  mock(instance).format_body_params!

                  dont_allow(instance).format_pagination_params!
                  dont_allow(instance).format_search_param!
                  dont_allow(instance).format_only_param!
                  dont_allow(instance).format_sort_order_params!
                  dont_allow(instance).format_optional_params!
                  dont_allow(instance).format_filter_params!
                end

                subject.call
              end
            end
          end

          describe '#formatting' do
            describe '#format_path_params' do
              context 'when no path params' do
                let(:endpoint_args) { { path: '/widgets(.:format)' } }

                it 'does any add path params to the output' do
                  subject.send(:format_path_params!)

                  expect(subject.output).to eq([])
                end
              end

              context 'when single path param is present' do
                let(:endpoint_args) { { path: '/widgets/:id(.:format)' } }

                it 'adds path params to the output' do
                  subject.send(:format_path_params!)

                  expect(subject.output).to eq([
                    {
                      'in'          => 'path',
                      'name'        => 'id',
                      'required'    => true,
                      'type'        => 'integer',
                      'description' => 'the ID of the Model'
                    }
                  ])
                end
              end

              context 'when multiple path params are present' do
                let(:endpoint_args) { { path: '/sprockets/:sprocket_id/widgets/:id(.:format)' } }

                it 'adds path params to the output' do
                  subject.send(:format_path_params!)

                  expect(subject.output).to eq([
                    {
                      'in'          => 'path',
                      'name'        => 'sprocket_id',
                      'required'    => true,
                      'type'        => 'integer',
                      'description' => 'the ID of the Sprocket'
                    },
                    {
                      'in'          => 'path',
                      'name'        => 'id',
                      'required'    => true,
                      'type'        => 'integer',
                      'description' => 'the ID of the Model'
                    }
                  ])
                end
              end
            end

            describe '#format_query_params' do
              let(:mocked_params_configuration_tree) do
                {
                  id: {
                    _config: {
                      type: 'integer',
                      info: 'The ID of the model   ',
                      required: true
                    }
                  },
                  sprocket_name: {
                    _config: {
                      type: 'string',
                      info: 'The name of the sprocket'
                    }
                  },
                  sprocket_ids: {
                    _config: {
                      type: 'array',
                      item_type: 'integer'
                    }
                  },
                  widget: {
                    _config: {
                      type: 'hash',
                    },
                    title: {
                      _config: {
                        type: 'string'
                      }
                    },
                  },
                }.with_indifferent_access
              end

              before do
                mock(endpoint).params_configuration_tree { mocked_params_configuration_tree }
              end

              it 'exclusively adds non-nested fields as query params' do
                subject.send(:format_query_params!)

                expect(subject.output).to eq([
                  {
                    'in'          => 'query',
                    'name'        => 'id',
                    'required'    => true,
                    'type'        => 'integer',
                    'format'      => 'int32',
                    'description' => 'The ID of the model'
                  },
                  {
                    'in'          => 'query',
                    'name'        => 'sprocket_name',
                    'type'        => 'string',
                    'description' => 'The name of the sprocket'
                  },
                  {
                    'in'          => 'query',
                    'name'        => 'sprocket_ids',
                    'type'        => 'array',
                    'items'       => { 'type' => 'integer' }
                  }
                ])
              end

              context 'when type of the param is unknown' do
                before do
                  mocked_params_configuration_tree[:id][:_config][:type] = 'invalid'
                end

                it 'raises an error' do
                  expect { subject.send(:format_query_params!) }.to raise_error(StandardError)
                end
              end
            end

            describe '#format_body_params' do
              let(:mocked_params_configuration_tree) do
                {
                  id: {
                    _config: {
                      type: 'integer'
                    }
                  },
                  task: {
                    _config: {
                      type: 'hash',
                      info: 'attributes for the task  '
                    },
                    name: {
                      _config: {
                        type: 'string',
                        required: true,
                        info: 'name of the task '
                      }
                    },
                    subs: {
                      _config: {
                        type: 'hash',
                        info: 'sub tasks of the task'
                      },
                      name: {
                        _config: {
                          type: 'string',
                          required: true
                        }
                      },
                    },
                    checklist: {
                      _config: {
                        type: 'array',
                        item: 'hash'
                      },
                      name: {
                        _config: {
                          type: 'string'
                        }
                      },
                    },
                  },
                }.with_indifferent_access
              end

              before do
                mock(endpoint).params_configuration_tree { mocked_params_configuration_tree }
              end

              it 'adds nested fields to the query params' do
                subject.send(:format_body_params!)

                expect(subject.output).to eq([
                  {
                    'in'          => 'body',
                    'required'    => true,
                    'name'        => 'task',
                    'description' => 'attributes for the task',
                    'schema'      => {
                      'type'       => 'object',
                      'properties' => {
                        'name' => {
                          'title'       => 'name',
                          'description' => 'name of the task',
                          'type'        => 'string'
                        },
                        'subs' => {
                          'title'       => 'subs',
                          'description' => 'sub tasks of the task',
                          'type'        => 'object',
                          'properties'  => {
                            'name' => {
                              'title'    => 'name',
                              'type'     => 'string'
                            }
                          }
                        },
                        'checklist' => {
                          'title'  => 'checklist',
                          'type'   => 'array',
                          'items'  => {
                            'type'       => 'object',
                            'properties' => {
                              'name' => {
                                'title'    => 'name',
                                'type'     => 'string'
                              }
                            }
                          }
                        }
                      }
                    },
                  }
                ])
              end
            end

            describe '#format_pagination_params!' do
              it 'adds the page & per_page query params' do
                subject.send(:format_pagination_params!)

                expect(subject.output).to eq([
                  {
                    'in'      => 'query',
                    'name'    => 'page',
                    'type'    => 'integer',
                    'format'  => 'int32',
                    'default' => 1
                  },
                  {
                    'in'      => 'query',
                    'name'    => 'per_page',
                    'type'    => 'integer',
                    'format'  => 'int32',
                    'default' => 20,
                    'maximum' => 200
                  }
                ])
              end
            end

            describe '#format_search_param!' do
              before do
                mock(presenter).searchable? { searchable }
              end

              context 'when presenter has search config' do
                let(:searchable) { true }

                it 'adds the search query params' do
                  subject.send(:format_search_param!)

                  expect(subject.output).to eq([
                    {
                      'in'   => 'query',
                      'name' => 'search',
                      'type' => 'string'
                    }
                  ])
                end
              end

              context 'when presenter has no search config' do
                let(:searchable) { false }

                it 'adds the search query params' do
                  subject.send(:format_search_param!)

                  expect(subject.output).to eq([])
                end
              end
            end

            describe '#format_optional_params!' do
              let(:optional_fields)  { ['field_1', 'field_2'] }

              before do
                mock(presenter).optional_field_names { optional_fields }
              end

              it 'adds the optional fields query param' do
                subject.send(:format_optional_params!)

                expect(subject.output).to eq([
                  {
                    'in'   => 'query',
                    'name' => 'optional_fields',
                    'description' => 'Allows you to request one or more optional fields as an array',
                    'type' => 'array',
                    'items' => {
                      'type' => 'string',
                      'enum' => optional_fields
                    }
                  }
                ])
              end
            end

            describe '#format_only_param!' do
              it 'adds the only query params' do
                subject.send(:format_only_param!)

                expect(subject.output).to eq([
                  {
                    'in'          => 'query',
                    'name'        => 'only',
                    'type'        => 'string',
                    'description' => 'Allows you to request one or more resources directly by IDs in a comma separated list'
                  }
                ])
              end
            end

            describe '#format_sort_order_params!' do
              before do
                mock(presenter).default_sort_order { 'title:asc' }
                mock(presenter).valid_sort_orders {
                  {
                    'title'         => { info: 'Order by title aphabetically' },
                    'sprocket_name' => { info: 'Order by sprocket name aphabetically' },
                  }
                }
              end

              it 'adds the sort order as query params' do
                subject.send(:format_sort_order_params!)

                expect(subject.output).to eq([
                  {
                    'in'          => 'query',
                    'name'        => 'order',
                    'description' => 'Supply `order` with the name of a valid sort field for the endpoint and a direction',
                    'type'        => 'array',
                    'items'       => {
                      'type'    => 'string',
                      'default' => 'title:asc',
                      'enum'    => ['sprocket_name:asc', 'sprocket_name:desc', 'title:asc', 'title:desc']
                    }
                  }
                ])
              end
            end

            describe '#format_filters' do
              let(:mocked_valid_filters) {
                {
                  filter_1: { type: 'string', info: 'Filter by string' },
                  filter_2: { type: 'boolean', default: false },
                  filter_3: { type: 'array', item_type: 'string', items: ['Option 1', 'Option 2'], default: 'Option 1' }
                }
              }

              before do
                mock(presenter).valid_filters { mocked_valid_filters }
              end

              it 'adds filters to the output as query params' do
                subject.send(:format_filter_params!)

                expect(subject.output).to eq([
                  {
                    'in'          => 'query',
                    'name'        => 'filter_1',
                    'type'        => 'string',
                    'description' => 'Filter by string'
                  },
                  {
                    'in'      => 'query',
                    'name'    => 'filter_2',
                    'type'    => 'boolean',
                    'default' => false
                  },
                  {
                    'in'      => 'query',
                    'name'    => 'filter_3',
                    'type'    => 'array',
                    'items'   => {
                      'type' => 'string',
                      'enum' => [
                        'Option 1',
                        'Option 2'
                      ],
                      'default' => 'Option 1'
                    }
                  }
                ])
              end
            end
          end
        end
      end
    end
  end
end
