require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_response_formatter'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        describe EndpointResponseFormatter do
          let(:controller)    { Object.new }
          let(:presenter)     { Object.new }
          let(:atlas)         { Object.new }
          let(:action)        { 'show' }
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
          end

          describe '#call' do
            context 'when action is destroy' do
              let(:action) { 'destroy' }

              it 'formats the delete response and error response' do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_destroy_response!
                  mock(instance).format_error_responses!

                  dont_allow(instance).format_schema_response!
                end

                subject.call
              end
            end

            context 'when action is not destroy' do
              let(:action) { 'show' }

              it 'formats the schema response and error response' do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_schema_response!
                  mock(instance).format_error_responses!

                  dont_allow(instance).format_destroy_response!
                end

                subject.call
              end
            end

          end

          describe '#formatting' do
            describe '#success_response_description' do
              subject { described_class.new(endpoint).send(:success_response_description) }

              context 'when action is index' do
                let(:action) { 'index' }

                it { is_expected.to eq('A list of Widgets have been retrieved') }
              end

              context 'when action is show' do
                let(:action) { 'show' }

                it { is_expected.to eq('Widget has been retrieved') }
              end

              context 'when action is update' do
                let(:action) { 'update' }

                it { is_expected.to eq('Widget has been updated') }
              end

              context 'when action is destroy' do
                let(:action) { 'destroy' }

                it { is_expected.to eq('Widget has been deleted') }
              end

              context 'when any other action' do
                let(:action) { 'update_all' }

                it { is_expected.to eq('A <string,MetaData> map of Widgets') }
              end
            end

            describe '#format_destroy_response!' do
              let(:action) { 'destroy' }

              it 'returns the structure response for a destroy action' do
                subject.send(:format_destroy_response!)

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
                  'description' => 'Widget has been retrieved',
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
          end
        end
      end
    end
  end
end
