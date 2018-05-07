require 'spec_helper'
require 'brainstem/api_docs/controller'

module Brainstem
  module ApiDocs
    describe Controller do
      subject       { described_class.new(atlas, options) }
      let(:atlas)   { Object.new }
      let(:options) { {} }

      describe "#initialize" do
        it "yields self if given a block" do
          block = Proc.new { |s| s.name = "bork bork" }
          expect(described_class.new(atlas, &block).name).to eq "bork bork"
        end
      end

      describe "#add_endpoint" do
        let(:endpoint) { Object.new }

        it "adds the endpoint to its list" do
          expect(subject.endpoints.count).to eq 0
          subject.add_endpoint(endpoint)
          expect(subject.endpoints.count).to eq 1
        end
      end

      describe "derived fields" do
        let(:lorem)          { "lorem ipsum dolor sit amet" }
        let(:const)          { Object.new }
        let(:default_config) { {} }
        let(:show_config)    { {} }
        let(:nodoc)          { false }
        let(:options)        { { const: const } }

        before do
          stub(const) do |constant|
            constant.configuration { {
              :_default => default_config,
              :show => show_config
            } }

            constant.to_s { "Api::V1::ClassName" }
          end
        end

        describe "configuration helpers" do
          describe "#contextual_documentation" do
            let(:default_config) { { title: { info: info, nodoc: nodoc } } }
            let(:info)           { lorem }

            context "when has the key" do
              let(:key) { :title }

              context "when not nodoc" do
                context "when has info" do
                  it "is truthy" do
                    expect(subject.contextual_documentation(key)).to be_truthy
                  end

                  it "is the info" do
                    expect(subject.contextual_documentation(key)).to eq lorem
                  end
                end

                context "when has no info" do
                  let(:info) { nil }

                  it "is falsey" do
                    expect(subject.contextual_documentation(key)).to be_falsey
                  end
                end
              end

              context "when nodoc" do
                let(:nodoc) { true }

                it "is falsey" do
                  expect(subject.contextual_documentation(key)).to be_falsey
                end
              end
            end

            context "when doesn't have the key" do
              let(:key) { :herp }

              it "is falsey" do
                expect(subject.contextual_documentation(key)).to be_falsey
              end
            end
          end

          describe "#default_configuration" do
            let(:default_config) { { title: nil } }

            it "returns the default key of the configuration" do
              expect(subject.default_configuration).to eq default_config
            end
          end
        end

        describe "#tag" do
          let(:default_config) { { tag: tag } }

          context "when tag in specified" do
            let(:tag) { 'Tag Name' }

            it "is true" do
              expect(subject.tag).to eq(tag)
            end
          end

          context "when tag is not specified" do
            let(:tag) { nil }

            it "is nil" do
              expect(subject.tag).to eq(nil)
            end
          end
        end

        describe "#tag_groups" do
          let(:default_config) { { tag_groups: tag_groups } }

          context "when tag groups are specified" do
            let(:tag_groups) { ['Group 1', 'Group 2'] }

            it "is true" do
              expect(subject.tag_groups).to eq(tag_groups)
            end
          end

          context "when tag_groups are not specified" do
            let(:tag_groups) { nil }

            it "is nil" do
              expect(subject.tag_groups).to eq(nil)
            end
          end
        end

        describe "#title" do
          context "when present" do
            let(:default_config) { { title: { info: lorem, nodoc: nodoc } } }

            context "when nodoc" do
              let(:nodoc) { true }

              it "falls back to the controller class" do
                expect(subject.title).to eq "ClassName"
              end
            end

            context "when documentable" do
              it "shows the title" do
                expect(subject.title).to eq lorem
              end
            end
          end

          context "when absent" do
            it "falls back to the controller class" do
              expect(subject.title).to eq "ClassName"
            end
          end
        end

        describe "#description" do
          context "when present" do
            let(:default_config) { { description: { info: lorem, nodoc: nodoc } } }

            context "when nodoc" do
              let(:nodoc) { true }

              it "shows nothing" do
                expect(subject.description).to eq ""
              end
            end

            context "when documentable" do
              it "shows the description" do
                expect(subject.description).to eq lorem
              end
            end
          end

          context "when absent" do
            it "shows nothing" do
              expect(subject.description).to eq ""
            end
          end
        end
      end

      describe "#suggested_filename" do
        let(:const)          { Object.new }

        before do
          stub(const) do |constant|
            constant.to_s { "Api::V1::ClassName" }
          end
        end

        it "gsubs namespace, filename and extension" do
          instance = described_class.new(atlas,
            filename_pattern: "controllers/{{namespace}}/{{name}}_controller.{{extension}}",
            name: 'api/v1/abc',
            const: const,
          )

          stub(instance).extension { "xyz" }

          expect(instance.suggested_filename(:xyz)).to \
            eq "controllers/api/v1/abc_controller.xyz"
        end
      end

      describe "#suggested_filename_link" do
        it "gsubs filename and extension" do

          instance = described_class.new(atlas,
            filename_link_pattern: "controllers/{{name}}_controller.{{extension}}.foo",
            name: 'abc'
          )

          stub(instance).extension { "xyz" }

          expect(instance.suggested_filename_link(:xyz)).to eq "controllers/abc_controller.xyz.foo"
        end
      end

      it_behaves_like "formattable"
      it_behaves_like "atlas taker"
    end
  end
end
