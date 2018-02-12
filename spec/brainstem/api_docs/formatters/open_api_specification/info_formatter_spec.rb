require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/info_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        describe InfoFormatter do
          let(:version) { 2 }

          subject { described_class.new(version: version) }

          describe 'call' do
            before do
              mock.proxy(subject).format_swagger_object!
              mock.proxy(subject).format_info_object!
            end

            it 'includes the correct top level attributes' do
              output = subject.call

              expect(output.keys).to match_array(%w(swagger host basePath schemes consumes produces info))
            end
          end

          describe 'format_swagger_object!' do
            before do
              mock.proxy(subject).host
              mock.proxy(subject).base_path
              mock.proxy(subject).schemes
              mock.proxy(subject).consumes
              mock.proxy(subject).produces
            end

            it 'includes the correct attributes' do
              swagger_object = subject.send(:format_swagger_object!)

              expect(swagger_object.keys).to match_array(%w(swagger host basePath schemes consumes produces))
            end
          end

          describe 'format_info_object!' do
            before do
              mock.proxy(subject).version
              mock.proxy(subject).title
              mock.proxy(subject).description
              mock.proxy(subject).terms_of_service
              mock.proxy(subject).contact_object
              mock.proxy(subject).license_object
            end

            it 'includes the top level info key' do
              output = subject.send(:format_info_object!)

              expect(output.keys).to eq(%w(info))
            end

            it 'includes the correct attributes' do
              info_object = subject.send(:format_info_object!)['info']

              expect(info_object.keys).to match_array(%w(version title description termsOfService contact license))
            end

            context 'when version is specified' do
              let(:version) { 2 }

              it 'sets the version attribute in the info object to the given value' do
                info_object = subject.send(:format_info_object!)['info']

                expect(info_object['version']).to eq(version)
              end
            end

            context 'when version is not specified' do
              let(:version) { nil }

              it 'defaults the version attribute in the info object to "1.0"' do
                info_object = subject.send(:format_info_object!)['info']

                expect(info_object['version']).to eq('1.0')
              end
            end
          end
        end
      end
    end
  end
end
