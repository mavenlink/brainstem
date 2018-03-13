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
          end

          describe '#call' do
            it 'formats path, query and body param for the endpoint' do
              any_instance_of(described_class) do |instance|
                mock(instance).format_path_params!
                mock(instance).format_query_params!
                mock(instance).format_body_params!
              end

              subject.call
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
                      'description' => "the ID of the Model"
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
                      'description' => "the ID of the Sprocket"
                    },
                    {
                      'in'          => 'path',
                      'name'        => 'id',
                      'required'    => true,
                      'type'        => 'integer',
                      'description' => "the ID of the Model"
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
                          'required'    => true,
                          'type'        => 'string'
                        },
                        'subs' => {
                          'title'       => 'subs',
                          'description' => 'sub tasks of the task',
                          'type'        => 'object',
                          'properties'  => {
                            'name' => {
                              'title'    => 'name',
                              'required' => true,
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
          end
        end
      end
    end
  end
end
