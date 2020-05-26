require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/endpoint/response_definitions_formatter'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module Endpoint
            describe ResponseDefinitionsFormatter do
              let(:controller)    { Object.new }
              let(:presenter)     { Object.new }
              let(:atlas)         { Object.new }
              let(:action)        { 'show' }
              let(:http_methods)  { %w(GET) }
              let(:endpoint)      {
                ::Brainstem::ApiDocs::Endpoint.new(
                  atlas,
                  endpoint_args
                )
              }
              let(:endpoint_args) { {} }
              let(:response_details) { {} }

              subject { described_class.new(endpoint) }

              before do
                stub(presenter).contextual_documentation(:title) { 'Widget' }
                stub(endpoint).presenter { presenter }
                stub(endpoint).action { action }
                stub(endpoint).custom_response_configuration_tree { {} }
                stub(endpoint).http_methods { http_methods }
                stub(endpoint).response_details { response_details }
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

                  context 'when response_details are specified' do
                    let(:response_details) { { object_name: 'Wizard' } }

                    context 'when action is show' do
                      let(:action) { 'show' }

                      it { is_expected.to eq('Wizard has been retrieved.') }
                    end

                    context 'when action is not show' do
                      let(:action) { 'index' }
                      let(:response_details) { { object_name: 'Wizard' } }

                      it { is_expected.to eq('A list of Wizards have been retrieved.') }
                    end

                    context 'when response_type is specified' do
                      let(:action) { 'custom' }

                      context 'when response_type is single' do
                        let(:response_details) { { object_name: 'Wizard', response_type: 'single' } }

                        it { is_expected.to eq('Wizard has been retrieved.') }
                      end

                      context 'when response_type is multi' do
                        let(:response_details) { { object_name: 'Wizard', response_type: 'multi' } }

                        it { is_expected.to eq('A list of Wizards have been retrieved.') }
                      end
                    end
                  end

                  context 'when `GET` request' do
                    let(:http_methods) { %w(GET) }

                    context 'when action is show' do
                      let(:action) { 'show' }

                      it { is_expected.to eq('Widget has been retrieved.') }
                    end

                    context 'when action is not show' do
                      let(:action) { 'index' }

                      it { is_expected.to eq('A list of Widgets have been retrieved.') }
                    end
                  end

                  context 'when `POST` request' do
                    let(:http_methods) { %w(POST) }

                    it { is_expected.to eq('Widget has been created.') }
                  end

                  context 'when `PUT` request' do
                    let(:http_methods) { %w(PUT) }

                    it { is_expected.to eq('Widget has been updated.') }
                  end

                  context 'when `PATCH` request' do
                    let(:http_methods) { %w(PATCH) }

                    it { is_expected.to eq('Widget has been updated.') }
                  end

                  context 'when `DELETE` request' do
                    let(:http_methods) { %w(DELETE) }

                    it { is_expected.to eq('Widget has been deleted.') }
                  end
                end

                describe '#format_delete_response!' do
                  let(:http_methods) { %w(DELETE) }

                  it 'returns the structure response for a destroy action' do
                    subject.send(:format_delete_response!)

                    expect(subject.output).to eq('204' => { 'description' => 'Widget has been deleted.' })
                  end
                end

                describe '#format_schema_response!' do
                  let(:action) { 'index' }

                  before do
                    stub(presenter).brainstem_keys { ['widgets'] }
                    stub(presenter).target_class { 'Widget' }
                    stub(presenter).valid_associations { {} }
                  end

                  it 'returns the structured response for an endpoint' do
                    subject.send(:format_schema_response!)

                    expect(subject.output).to eq('200' => {
                      'description' => 'A list of Widgets have been retrieved.',
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

                  context 'when there are valid associations' do
                    let(:task_stubbed_presenter) { Object.new }
                    let(:user_stubbed_presenter) { Object.new }
                    let(:nodoc) { false }

                    before do
                      stub(task_stubbed_presenter).nodoc? { nodoc }
                      stub(task_stubbed_presenter).brainstem_keys { ['tasks'] }
                      stub(user_stubbed_presenter).nodoc? { nodoc }
                      stub(user_stubbed_presenter).brainstem_keys { ['users'] }
                      stub(presenter).find_by_class(Task) { task_stubbed_presenter }
                      stub(presenter).find_by_class(User) { user_stubbed_presenter }
                    end

                    context 'when association is pointing to a nodoc class' do
                      let(:nodoc) { true }

                      it 'does not generate references for the association' do
                        subject.send(:format_schema_response!)

                        expect(subject.output).to eq('200' => {
                          'description' => 'A list of Widgets have been retrieved.',
                          'schema' => {
                            'type' => 'object',
                            'properties' => {
                              'count' => { 'type' => 'integer', 'format' => 'int32' },
                              'meta' => {
                                'type' => 'object',
                                'properties' => {
                                  'count' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_count' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_number' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_size' => { 'type' => 'integer', 'format' => 'int32' },
                                }
                              },
                              'results' => {
                                'type' => 'array',
                                'items' => {
                                  'type' => 'object',
                                  'properties' => {
                                    'key' => { 'type' => 'string' },
                                    'id' => { 'type' => 'string' }
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

                    context 'when the association is polymorphic' do
                      before do
                        stub(presenter).valid_associations { { 'tasks' => ::Brainstem::DSL::Association.new('polymorphic', :polymorphic, polymorphic_classes: [Task, User]) } }
                      end

                      it 'returns the appropriate associations with their additional properties' do
                        subject.send(:format_schema_response!)

                        expect(subject.output).to eq('200' => {
                          'description' => 'A list of Widgets have been retrieved.',
                          'schema' => {
                            'type' => 'object',
                            'properties' => {
                              'count' => { 'type' => 'integer', 'format' => 'int32' },
                              'meta' => {
                                'type' => 'object',
                                'properties' => {
                                  'count' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_count' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_number' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_size' => { 'type' => 'integer', 'format' => 'int32' },
                                }
                              },
                              'results' => {
                                'type' => 'array',
                                'items' => {
                                  'type' => 'object',
                                  'properties' => {
                                    'key' => { 'type' => 'string' },
                                    'id' => { 'type' => 'string' }
                                  }
                                }
                              },
                              'widgets' => {
                                'type' => 'object',
                                'additionalProperties' => {
                                  '$ref' => '#/definitions/Widget'
                                }
                              },
                              'tasks' => {
                                'type' => 'object',
                                'additionalProperties' => {
                                  '$ref' => '#/definitions/Task'
                                }
                              },
                              'users' => {
                                'type' => 'object',
                                'additionalProperties' => {
                                  '$ref' => '#/definitions/User'
                                }
                              }
                            }
                          }
                        })
                      end
                    end

                    context 'when the association is not polymorphic' do
                      before do
                        stub(presenter).valid_associations { { 'tasks' => ::Brainstem::DSL::Association.new('Task', Task, {}) } }
                      end

                      it 'returns the appropriate association with its additional properties' do
                        subject.send(:format_schema_response!)

                        expect(subject.output).to eq('200' => {
                          'description' => 'A list of Widgets have been retrieved.',
                          'schema' => {
                            'type' => 'object',
                            'properties' => {
                              'count' => { 'type' => 'integer', 'format' => 'int32' },
                              'meta' => {
                                'type' => 'object',
                                'properties' => {
                                  'count' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_count' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_number' => { 'type' => 'integer', 'format' => 'int32' },
                                  'page_size' => { 'type' => 'integer', 'format' => 'int32' },
                                }
                              },
                              'results' => {
                                'type' => 'array',
                                'items' => {
                                  'type' => 'object',
                                  'properties' => {
                                    'key' => { 'type' => 'string' },
                                    'id' => { 'type' => 'string' }
                                  }
                                }
                              },
                              'widgets' => {
                                'type' => 'object',
                                'additionalProperties' => {
                                  '$ref' => '#/definitions/Widget'
                                }
                              },
                              'tasks' => {
                                'type' => 'object',
                                'additionalProperties' => {
                                  '$ref' => '#/definitions/Task'
                                }
                              }
                            }
                          }
                        })
                      end
                    end
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
                  let(:action) { 'index' }

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
                              'info' => 'The name of the widget.',
                              'nodoc' => false
                            },
                          },
                          'widget_permission' => {
                            '_config' => {
                              'type' => 'hash',
                              'info' => 'The permissions of the widget.',
                              'nodoc' => false
                            },
                            'can_edit' => {
                              '_config' => {
                                'type' => 'boolean',
                                'info' => 'Can edit the widget.',
                                'nodoc' => false
                              },
                            },
                            '_dynamic_key' => {
                              '_config' => {
                                'type' => 'array',
                                'item_type' => 'integer',
                                'info' => 'Viewable Widget Ids.',
                                'nodoc' => false,
                                'dynamic_key' => true
                              },
                            },
                          },
                          '_dynamic_key' => {
                            '_config' => {
                              'type' => 'array',
                              'item_type' => 'integer',
                              'info' => 'Association Ids.',
                              'nodoc' => false,
                              'dynamic_key' => true
                            },
                          },
                        }.with_indifferent_access
                      }
                    end

                    it 'returns the response structure' do
                      subject.send(:format_custom_response!)

                      expect(subject.output).to eq('200' => {
                        'description' => 'A list of Widgets have been retrieved.',
                        'schema' => {
                          'type' => 'object',
                          'properties' => {
                            'widget_name' => {
                              'type' => 'string',
                              'description' => 'The name of the widget.'
                            },
                            'widget_permission' => {
                              'type' => 'object',
                              'description' => 'The permissions of the widget.',
                              'properties' => {
                                'can_edit' => {
                                  'type' => 'boolean',
                                  'description' => 'Can edit the widget.'
                                }
                              },
                              'additionalProperties' => {
                                'type' => 'array',
                                'description' => 'Viewable Widget Ids.',
                                'items' => {
                                  'type' => 'integer',
                                  'format' => 'int32',
                                }
                              },
                            }
                          },
                          'additionalProperties' => {
                            'type' => 'array',
                            'description' => 'Association Ids.',
                            'items' => {
                              'type' => 'integer',
                              'format' => 'int32',
                            }
                          },
                        }
                      })
                    end
                  end

                  context 'when the response is an array' do
                    context 'when array of string / number' do
                      before do
                        stub(endpoint).custom_response_configuration_tree {
                          {
                            '_config' => {
                              'type' => 'array',
                              'item_type' => 'string',
                            },
                          }.with_indifferent_access
                        }
                      end

                      it 'returns the response structure' do
                        subject.send(:format_custom_response!)

                        expect(subject.output).to eq('200' => {
                          'description' => 'A list of Widgets have been retrieved.',
                          'schema' => {
                            'type' => 'array',
                            'items' => {
                              'type' => 'string',
                            }
                          }
                        })
                      end
                    end

                    context 'when array of hashes' do
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
                                'info' => 'The name of the widget.',
                                'nodoc' => false
                              },
                            },
                            'widget_permissions' => {
                              '_config' => {
                                'type' => 'array',
                                'item_type' => 'hash',
                                'info' => 'The permissions of the widget.',
                                'nodoc' => false
                              },
                              'can_edit' => {
                                '_config' => {
                                  'type' => 'boolean',
                                  'info' => 'Can edit the widget.',
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
                        'description' => 'A list of Widgets have been retrieved.',
                        'schema' => {
                          'type' => 'array',
                          'items' => {
                            'type' => 'object',
                            'properties' => {
                              'widget_name' => {
                                'type' => 'string',
                                'description' => 'The name of the widget.'
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
                          }
                        }
                      })
                      end
                    end
                  end

                  context 'when the response is multi nested array' do
                    before do
                      stub(endpoint).custom_response_configuration_tree { response_config_tree }
                    end

                    # response :array, nested_level: 2, item_type: [:hash, :string, :integer] do
                    #   nested.field :a, :string
                    #   nested.field :b, :integer
                    # end
                    
                    # response :array, nested_level: 2, item_type: :hash do
                    #   nested.field :a, :string
                    #   nested.field :a, :integer
                    # end
                    # 
                    # [
                    #   [
                    #     { widget_name: 'Widget A', can_edit: false },
                    #     { widget_name: 'Widget B', can_edit: true },
                    #   ]
                    # ]
                    context 'when the leaf array is an array of objects' do
                      let(:response_config_tree) do
                        {
                          '_config' => {
                            'type' => 'array',
                            'nested_levels' => 2,
                            'item_type' => 'hash',
                          },
                          'widget_name' => {
                            '_config' => {
                              'type' => 'string',
                              'info' => 'The name of the widget.',
                              'nodoc' => false
                            },
                          },
                          'widget_permissions' => {
                            '_config' => {
                              'type' => 'array',
                              'item_type' => 'hash',
                              'info' => 'The permissions of the widget.',
                              'nodoc' => false
                            },
                            'can_edit' => {
                              '_config' => {
                                'type' => 'array',
                                'nested_levels' => 3,
                                'item_type' => 'boolean',
                                'nodoc' => false
                              },
                            }
                          },
                        }.with_indifferent_access
                      end

                      it 'returns the response structure' do
                        subject.send(:format_custom_response!)

                        expect(subject.output).to eq('200' => {
                          'description' => 'A list of Widgets have been retrieved.',
                          'schema' => {
                            'type' => 'array',
                            'items' => {
                              'type' => 'array',
                              'items' => {
                                'type' => 'object',
                                'properties' => {
                                  'widget_name' => {
                                    'type' => 'string',
                                    'description' => 'The name of the widget.'
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
                          }
                        })
                      end
                    end

                    # response :array, nested_level: 3, item_type: :string
                    # 
                    # [
                    #   [
                    #     [1,3,4,5],
                    #     [6,7,8,9],
                    #   ]
                    # ]
                    context 'when the leaf array is an array of strings' do
                      let(:response_config_tree) do
                        {
                          '_config' => {
                            'type' => 'array',
                            'nested_levels' => 3,
                            'item_type' => 'string',
                          },
                        }.with_indifferent_access
                      end

                      it 'returns the response structure' do
                        subject.send(:format_custom_response!)

                        expect(subject.output).to eq('200' => {
                          'description' => 'A list of Widgets have been retrieved.',
                          'schema' => {
                            'type' => 'array',
                            'items' => {
                              'type' => 'array',
                              'items' => {
                                'type' => 'array',
                                'items' => {
                                  'type' => 'string',
                                }
                              }
                            }
                          }
                        })
                      end
                    end
                  end

                  context 'when the response is not a hash or an array' do
                    before do
                      stub(endpoint).custom_response_configuration_tree {
                        {
                          '_config' => {
                            'type' => 'integer',
                            'info' => 'Indicates the number of widgets',
                            'nodoc' => false
                          },
                        }.with_indifferent_access
                      }
                    end

                    it 'returns the response structure' do
                      subject.send(:format_custom_response!)

                      expect(subject.output).to eq('200' => {
                        'description' => 'A list of Widgets have been retrieved.',
                        'schema' => {
                          'type' => 'integer',
                          'format' => 'int32',
                          'description' => 'Indicates the number of widgets.'
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
end
