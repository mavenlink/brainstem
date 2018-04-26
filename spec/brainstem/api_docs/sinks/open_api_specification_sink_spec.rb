require 'spec_helper'
require 'brainstem/api_docs/sinks/open_api_specification_sink'
require 'brainstem/api_docs/formatters/open_api_specification/info_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/security_definitions_formatter'

module Brainstem
  module ApiDocs
    module Sinks
      describe OpenApiSpecificationSink do
        let(:write_method) { Object.new }
        let(:atlas)        { Object.new}
        let(:options)      {
          {
            api_version:  '2.0.0',
            write_method: write_method,
            write_path:   './'
          }
        }

        subject { described_class.new(options) }

        it "calls the write method" do
          mock(subject).write_info_object!
          mock(subject).write_presenter_definitions!
          mock(subject).write_error_definitions!
          mock(subject).write_endpoint_definitions!
          mock(subject).write_tag_definitions!
          mock(subject).write_security_definitions!

          mock.proxy(subject).write_spec_to_file!
          mock(write_method).call('./specification.yml', anything)

          subject << atlas
        end

        describe "specification" do
          let(:generated_data) { { 'sprockets' => { 'type' => 'object' } } }

          before do
            mock.proxy(subject).write_spec_to_file!
          end

          it "writes the data returned from the info formatter" do
            mock(subject).write_presenter_definitions!
            mock(subject).write_error_definitions!
            mock(subject).write_endpoint_definitions!
            mock(subject).write_tag_definitions!
            mock(subject).write_security_definitions!

            mock.proxy(subject).write_info_object!
            mock.proxy
              .any_instance_of(Brainstem::ApiDocs::Formatters::OpenApiSpecification::InfoFormatter)
              .call { generated_data }
            mock(write_method).call('./specification.yml', generated_data.to_yaml)

            subject << atlas
          end

          context "when generating schema definitions" do
            let(:generated_data) {
              [
                { 'widgets'   => { 'type' => 'object' } },
                { 'sprockets' => { 'type' => 'object' } }
              ]
            }
            let(:expected_yaml) {
              {
                'definitions' => {
                  'sprockets' => { 'type' => 'object' },
                  'widgets'   => { 'type' => 'object' }
                }
              }.to_yaml
            }

            it "writes presenter definitions" do
              mock(subject).write_info_object!
              mock(subject).write_error_definitions!
              mock(subject).write_endpoint_definitions!
              mock(subject).write_tag_definitions!
              mock(subject).write_security_definitions!

              mock.proxy(subject).write_presenter_definitions!
              stub(atlas).presenters.stub!.formatted(:oas) { generated_data }
              mock(write_method).call('./specification.yml', expected_yaml)

              subject << atlas
            end
          end

          context "when generating error definitions" do
            let(:generated_data) {
              [
                { 'widgets'   => { 'type' => 'object' } },
                { 'sprockets' => { 'type' => 'object' } }
              ]
            }
            let(:expected_yaml) {
              {
                'definitions' => {
                  'sprockets' => { 'type' => 'object' },
                  'widgets'   => { 'type' => 'object' },
                  'Error'     => {
                    'type' => 'object',
                    'properties' => {
                      'type'    => { 'type' => 'string' },
                      'message' => { 'type' => 'string' },
                    }
                  },
                  'Errors' => {
                    'type' => 'object',
                    'properties' => {
                      'errors' => {
                        'type'  => 'array',
                        'items' => {
                          '$ref' => '#/definitions/Error'
                        }
                      }
                    }
                  },
                }
              }.to_yaml
            }

            it "writes error definitions" do
              mock(subject).write_info_object!
              mock(subject).write_endpoint_definitions!
              mock(subject).write_tag_definitions!
              mock(subject).write_security_definitions!

              mock.proxy(subject).write_presenter_definitions!
              mock.proxy(subject).write_error_definitions!

              stub(atlas).presenters.stub!.formatted(:oas) { generated_data }
              mock(write_method).call('./specification.yml', expected_yaml)

              subject << atlas
            end
          end

          context "when generating endpoint definitions" do
            let(:generated_data) {
              [
                { '/widgets'   => { 'get'  => { 'type' => 'object' } } },
                { '/sprockets' => { 'post' => { 'type' => 'object' } } }
              ]
            }
            let(:expected_yaml) {
              {
                'paths' => {
                  '/sprockets' => { 'post' => { 'type' => 'object' } },
                  '/widgets'   => { 'get'  => { 'type' => 'object' } }
                }
              }.to_yaml
            }

            it "writes endpoint definitions" do
              mock(subject).write_info_object!
              mock(subject).write_error_definitions!
              mock(subject).write_presenter_definitions!
              mock(subject).write_tag_definitions!
              mock(subject).write_security_definitions!
              mock.proxy(subject).write_endpoint_definitions!

              stub(atlas).controllers.stub!.formatted(:oas) { generated_data }
              mock(write_method).call('./specification.yml', expected_yaml)

              subject << atlas
            end
          end

          context "when generating tag definitions" do
            let(:documentable_controller_Z) {
              OpenStruct.new(
                name:        'controller_Z',
                description: 'controller_Z desc',
                endpoints:   OpenStruct.new(only_documentable: [1, 2])
              )
            }
            let(:documentable_controller_A) {
              OpenStruct.new(
                name:        'controller_A',
                description: 'controller_A desc',
                endpoints:   OpenStruct.new(only_documentable: [1, 2])
              )
            }
            let(:nodoc_controller) {
              OpenStruct.new(
                name:        'controller_nodoc',
                description: 'controller_nodoc desc',
                endpoints:   OpenStruct.new(only_documentable: [1, 2])
              )
            }
            let(:no_endpoint_controller) {
              OpenStruct.new(
                name:        'controller_no_endpoint',
                description: 'controller_no_endpoint desc',
                endpoints:   OpenStruct.new(only_documentable: [])
              )
            }
            let(:controllers) {
              [
                documentable_controller_Z,
                documentable_controller_A,
                nodoc_controller,
                no_endpoint_controller
              ]
            }
            let(:expected_yaml) {
              {
                'tags' => [
                  { 'name' => 'Controller A', 'description' => 'controller_A desc' },
                  { 'name' => 'Controller Z', 'description' => 'controller_Z desc' }
                ]
              }.to_yaml
            }

            before do
              stub(nodoc_controller).nodoc? { true }
            end

            it "writes endpoint definitions" do
              mock(subject).write_info_object!
              mock(subject).write_error_definitions!
              mock(subject).write_presenter_definitions!
              mock(subject).write_endpoint_definitions!
              mock(subject).write_security_definitions!

              mock.proxy(subject).write_tag_definitions!
              stub(atlas).controllers { controllers }
              mock(write_method).call('./specification.yml', expected_yaml)

              subject << atlas
            end
          end

          context "when generating security definitions" do
            let(:expected_yaml) {
              {
                'securityDefinitions' => {
                  'api_key' => {
                    'type' => 'apiKey',
                    'name' => 'api_key',
                    'in'   => 'header'
                  },
                  'petstore_auth' => {
                    'type'             => 'oauth2',
                    'authorizationUrl' => 'http://petstore.swagger.io/oauth/dialog',
                    'flow'             => 'implicit',
                    'scopes'           => {
                      'write:pets' => 'modify pets in your account',
                      'read:pets'  => 'read your pets'
                    }
                  }
                }
              }.to_yaml
            }

            it "writes endpoint definitions" do
              mock(subject).write_info_object!
              mock(subject).write_error_definitions!
              mock(subject).write_presenter_definitions!
              mock(subject).write_tag_definitions!
              mock(subject).write_endpoint_definitions!

              mock.proxy(subject).write_security_definitions!
              stub(atlas).controllers.stub!.formatted(:oas) { generated_data }
              mock(write_method).call('./specification.yml', expected_yaml)

              subject << atlas
            end
          end
        end

        describe "versioning" do
          let(:options) {
            {
              api_version:  api_version,
              write_method: write_method,
              write_path:   './'
            }
          }

          before do
            stub(subject).write_spec_to_file!
          end

          context "when version is specified" do
            let(:api_version) { '2.1.1' }

            it "returns the specified version" do
              expect(subject.send(:formatted_version)).to eq(api_version)
            end
          end

          context "when version is not specified" do
            let(:api_version) { nil }

            it "returns the default version" do
              expect(subject.send(:formatted_version)).to eq('1.0.0')
            end
          end
        end
      end
    end
  end
end
