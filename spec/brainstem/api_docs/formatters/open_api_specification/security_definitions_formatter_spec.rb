require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/security_definitions_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        describe SecurityDefinitionsFormatter do
          subject { described_class.new }

          describe 'call' do
            before do
              mock.proxy(subject).format_basic_auth_definitions!
              mock.proxy(subject).format_apikey_auth_definitions!
              mock.proxy(subject).format_oauth_definitions!
              mock.proxy(subject).format_security_object!
            end

            it 'includes security definitions' do
              output = subject.call
            end
          end

          describe 'format_basic_auth_definitions!' do
            context 'when definition exists' do
              let(:basic_auth_definition) { { 'basic' => { 'type' => 'basic' } } }

              before do
                mock(subject).basic_auth_definitions { basic_auth_definition }
              end

              it 'includes the correct attributes' do
                subject.send(:format_basic_auth_definitions!)

                expect(subject.output.keys).to match_array(%w(securityDefinitions))
                expect(subject.output['securityDefinitions']).to eq(basic_auth_definition)
              end
            end

            context 'when definition is blank' do
              before do
                mock.proxy(subject).basic_auth_definitions
              end

              it 'does not add securityDefinitions key' do
                subject.send(:format_basic_auth_definitions!)

                expect(subject.output).to be_empty
              end
            end
          end

          describe 'format_apikey_auth_definitions!' do
            context 'when definition exists' do
              before do
                mock.proxy(subject).apikey_auth_definitions
              end

              it 'includes the correct attributes' do
                subject.send(:format_apikey_auth_definitions!)

                expect(subject.output.keys).to match_array(%w(securityDefinitions))
                expect(subject.output['securityDefinitions']).to eq({
                  'api_key' => {
                    'type' => 'apiKey',
                    'name' => 'api_key',
                    'in'   => 'header'
                  }
                })
              end
            end

            context 'when definition is blank' do
              before do
                mock(subject).apikey_auth_definitions { {} }
              end

              it 'does not add securityDefinitions key' do
                subject.send(:format_apikey_auth_definitions!)

                expect(subject.output).to be_empty
              end
            end
          end

          describe 'format_apikey_auth_definitions!' do
            context 'when definition exists' do
              before do
                mock.proxy(subject).apikey_auth_definitions
              end

              it 'includes the correct attributes' do
                subject.send(:format_apikey_auth_definitions!)

                expect(subject.output.keys).to match_array(%w(securityDefinitions))
                expect(subject.output['securityDefinitions']).to eq({
                  'api_key' => {
                    'type' => 'apiKey',
                    'name' => 'api_key',
                    'in'   => 'header'
                  }
                })
              end
            end

            context 'when definition is blank' do
              before do
                mock(subject).apikey_auth_definitions { {} }
              end

              it 'does not add securityDefinitions key' do
                subject.send(:format_apikey_auth_definitions!)

                expect(subject.output).to be_empty
              end
            end
          end

          describe 'format_oauth_definitions!' do
            context 'when definition exists' do
              before do
                mock.proxy(subject).oauth_definitions
              end

              it 'includes the correct attributes' do
                subject.send(:format_oauth_definitions!)

                expect(subject.output.keys).to match_array(%w(securityDefinitions))
                expect(subject.output['securityDefinitions']).to eq({
                  'petstore_auth' => {
                    'type'             => 'oauth2',
                    'authorizationUrl' => 'http://petstore.swagger.io/oauth/dialog',
                    'flow'             => 'implicit',
                    'scopes'           => {
                      'write:pets' => 'modify pets in your account',
                      'read:pets'  => 'read your pets'
                    }
                  }
                })
              end
            end

            context 'when definition is blank' do
              before do
                mock(subject).oauth_definitions { {} }
              end

              it 'does not add securityDefinitions key' do
                subject.send(:format_oauth_definitions!)

                expect(subject.output).to be_empty
              end
            end
          end

          describe 'format_security_object!' do
            context 'when definition exists' do
              let(:security_object) { { 'petstore_auth' => ['write:pets', 'read:pets'] } }

              before do
                mock(subject).security_object { security_object }.times(2)
              end

              it 'includes the correct attributes' do
                subject.send(:format_security_object!)

                expect(subject.output.keys).to match_array(%w(security))
                expect(subject.output['security']).to eq(security_object)
              end
            end

            context 'when definition is blank' do
              before do
                mock.proxy(subject).security_object
              end

              it 'does not add security key' do
                subject.send(:format_security_object!)

                expect(subject.output).to be_empty
              end
            end
          end
        end
      end
    end
  end
end
