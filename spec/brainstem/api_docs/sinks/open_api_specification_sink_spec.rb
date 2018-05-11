require 'spec_helper'
require 'brainstem/api_docs/sinks/open_api_specification_sink'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/info_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/security_definitions_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/tags_formatter'

module Brainstem
  module ApiDocs
    module Sinks
      describe OpenApiSpecificationSink do
        let(:write_method)    { Object.new }
        let(:atlas)           { Object.new }
        let(:options)         { default_options }
        let(:default_options) {
          {
            api_version:  '2.0.0',
            format:       :oas_v2,
            write_method: write_method,
            write_path:   './',
          }
        }

        subject { described_class.new(options) }

        context "writing the specification" do
          before do
            mock(subject).write_info_object!
            mock(subject).write_presenter_definitions!
            mock(subject).write_error_definitions!
            mock(subject).write_endpoint_definitions!
            mock(subject).write_tag_definitions!
            mock(subject).write_security_definitions!

            mock.proxy(subject).write_spec_to_file!
          end

          it "calls the write method" do
            mock(write_method).call('./specification.yml', anything)

            subject << atlas
          end

          context "when a filename pattern is specified" do
            let(:options) {
              default_options.merge(
                api_version: "1.1.0",
                oas_filename_pattern: "specification_{{version}}.{{extension}}",
                output_extension: "json"
              )
            }

            it "calls the write method with customized filename" do
              mock(write_method).call('./specification_1.1.0.json', anything)

              subject << atlas
            end
          end

          context "when a output extension is specified" do
            let(:options) { default_options.merge(output_extension: output_extension) }

            context "when valid extension is specified" do
              let(:output_extension) { 'JSON' }

              it "calls the write method with the correct file extension" do
                mock(write_method).call('./specification.json', anything)

                subject << atlas
              end
            end

            context "when unsupported extension is specified" do
              let(:output_extension) { 'JSON' }

              it "raises an error" do
                expect { subject << atlas }.to raise_error
              end
            end
          end
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
              .any_instance_of(Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::InfoFormatter)
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
              stub(atlas).presenters.stub!.formatted(:oas_v2) { generated_data }
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

              stub(atlas).presenters.stub!.formatted(:oas_v2) { generated_data }
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

              stub(atlas).controllers.stub!.formatted(:oas_v2) { generated_data }
              mock(write_method).call('./specification.yml', expected_yaml)

              subject << atlas
            end
          end

          context "when generating tag definitions" do
            let(:documentable_controller_Z) {
              OpenStruct.new(
                name:        'controller_Z',
                description: 'controller_Z desc',
                endpoints:   OpenStruct.new(only_documentable: [1, 2]),
                tag:         'Tag Z',
                tag_groups:  ['Group Z'],
              )
            }
            let(:documentable_controller_A) {
              OpenStruct.new(
                name:        'controller_A',
                description: 'controller_A desc',
                endpoints:   OpenStruct.new(only_documentable: [1, 2]),
                tag:         'Tag A',
                tag_groups:  ['Group Z', 'Group A'],
              )
            }
            let(:controllers) {
              [
                documentable_controller_Z,
                documentable_controller_A,
              ]
            }
            let(:expected_yaml) {
              {
                'tags' => [
                  { 'name' => 'Tag A', 'description' => 'Controller_A desc.' },
                  { 'name' => 'Tag Z', 'description' => 'Controller_Z desc.' }
                ],
                'x-tagGroups' => [
                  { 'name' => 'Group A', 'tags' => ['Tag A'] },
                  { 'name' => 'Group Z', 'tags' => ['Tag A', 'Tag Z'] }
                ],
              }.to_yaml
            }
            let(:ignore_tagging) { false }
            let(:options) { default_options.merge(ignore_tagging: ignore_tagging) }

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
              stub(atlas).controllers.stub!.formatted(:oas_v2) { generated_data }
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

        describe "suggested_filename" do
          let(:options) {
            default_options.merge(
              api_version: '1.1.1',
              oas_filename_pattern: oas_filename_pattern
            )
          }

          before do
            stub(subject).write_spec_to_file!
          end

          context "when version is specified" do
            let(:oas_filename_pattern) { "{{version}}.{{extension}}" }

            it "returns the customized filename" do
              expect(subject.send(:suggested_filename)).to eq("1.1.1.yml")
            end
          end

          context "when version is not specified" do
            let(:oas_filename_pattern) { nil }

            it "returns the default filename" do
              expect(subject.send(:suggested_filename)).to eq('specification.yml')
            end
          end
        end
      end
    end
  end
end
