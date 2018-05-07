require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/tags_formatter'
require 'brainstem/api_docs/controller'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          describe TagsFormatter do
            let(:atlas)        { Object.new }
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
            let(:nodoc_controller) {
              OpenStruct.new(
                name:        'controller_nodoc',
                description: 'controller_nodoc desc',
                endpoints:   OpenStruct.new(only_documentable: [1, 2]),
                tag:         'No Doc',
                tag_groups:  ['No Doc Group'],
              )
            }
            let(:no_endpoint_controller) {
              OpenStruct.new(
                name:        'controller_no_endpoint',
                description: 'controller_no_endpoint desc',
                endpoints:   OpenStruct.new(only_documentable: []),
                tag:         'No Endpoint',
                tag_groups:  ['No Endpoint Group'],
              )
            }
            let(:no_tag_controller) {
              OpenStruct.new(
                name:        'no_tag_controller',
                description: 'no_tag_controller desc',
                endpoints:   OpenStruct.new(only_documentable: [1])
              )
            }
            let(:controllers) {
              [
                documentable_controller_Z,
                documentable_controller_A,
                nodoc_controller,
                no_endpoint_controller,
                no_tag_controller
              ]
            }
            let(:ignore_tagging) { false }
            let(:options)        { { ignore_tagging: ignore_tagging } }

            def extract_tag_names(tags)
              tags.map { |tag| tag['name'] }
            end

            subject { described_class.new(controllers, options) }

            before do
              stub(nodoc_controller).nodoc? { true }
            end

            describe 'call' do
              describe 'when ignore tags option is selected' do
                let(:ignore_tagging) { true }

                before do
                  dont_allow(subject).format_tags!
                  dont_allow(subject).format_tag_groups!
                end

                it 'returns empty object' do
                  expect(subject.call).to be_empty
                end
              end

              describe 'when no controllers are passed in' do
                let(:controllers) { [] }

                before do
                  dont_allow(subject).format_tags!
                  dont_allow(subject).format_tag_groups!
                end

                it 'returns empty object' do
                  expect(subject.call).to be_empty
                end
              end

              describe 'when controllers are present and ignore tags is false' do
                before do
                  mock(subject).format_tags!
                  mock(subject).format_tag_groups!
                end

                it 'includes tag definitions' do
                  subject.call
                end
              end
            end

            describe '#format_tags!' do
              it 'excludes no doc controllers' do
                subject.send(:format_tags!)

                expect(subject.output).to have_key('tags')
                expect(extract_tag_names(subject.output['tags'])).to_not include('No Doc')
              end

              it 'excludes controllers with no documentable endpoints' do
                subject.send(:format_tags!)

                expect(subject.output).to have_key('tags')
                expect(extract_tag_names(subject.output['tags'])).to_not include('No Endpoint')
              end

              it 'returns a array of tags sorted by name of the tag' do
                subject.send(:format_tags!)

                expect(subject.output).to have_key('tags')
                expect(subject.output['tags']).to eq([
                  {
                    'name' => 'No Tag Controller',
                    'description' => 'No_tag_controller desc.'
                  },
                  {
                    'name' => 'Tag A',
                    'description' => 'Controller_a desc.'
                  },
                  {
                    'name' => 'Tag Z',
                    'description' => 'Controller_z desc.'
                  },
                ])
              end
            end

            describe '#format_tag_groups!!' do
              it 'excludes no doc controllers' do
                subject.send(:format_tag_groups!)

                expect(subject.output).to have_key('x-tagGroups')
                expect(extract_tag_names(subject.output['x-tagGroups'])).to_not include('No Doc Group')
              end

              it 'excludes controllers with no documentable endpoints' do
                subject.send(:format_tag_groups!)

                expect(subject.output).to have_key('x-tagGroups')
                expect(extract_tag_names(subject.output['x-tagGroups'])).to_not include('No Endpoint Group')
              end

              it 'returns a array of tag groups sorted by name of the group name' do
                subject.send(:format_tag_groups!)

                expect(subject.output).to have_key('x-tagGroups')
                expect(subject.output['x-tagGroups']).to eq([
                  {
                    'name' => 'Group A',
                    'tags' => ['Tag A']
                  },
                  {
                    'name' => 'Group Z',
                    'tags' => ['Tag A', 'Tag Z']
                  },
                  {
                    'name' => 'No Tag Controller',
                    'tags' => ['No Tag Controller']
                  },
                ])
              end

              context 'when none of the controllers have tag groups specified' do
                let(:documentable_controller_Z) {
                  OpenStruct.new(
                    name:        'controller_Z',
                    description: 'controller_Z desc',
                    endpoints:   OpenStruct.new(only_documentable: [1, 2]),
                    tag:         'Tag Z',
                  )
                }
                let(:documentable_controller_A) {
                  OpenStruct.new(
                    name:        'controller_A',
                    description: 'controller_A desc',
                    endpoints:   OpenStruct.new(only_documentable: [1, 2]),
                    tag:         'Tag A',
                  )
                }

                it 'does not add tag groups to the output' do
                  subject.send(:format_tag_groups!)

                  expect(subject.output).to_not have_key('x-tagGroups')
                end
              end
            end
          end
        end
      end
    end
  end
end
