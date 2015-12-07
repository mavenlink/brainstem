require 'spec_helper'
require 'brainstem/api_docs/controller'

module Brainstem
  module ApiDocs
    describe Controller do
      describe "#initialize" do
        it "yields self if given a block" do
          block = Proc.new { |s| s.name = "bork bork" }
          expect(described_class.new(&block).name).to eq "bork bork"
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

        subject              { described_class.new(const: const) }

        before do
          stub(const) do |constant|
            constant.configuration { {
              :_default => default_config,
              :show => show_config
            } }

            constant.to_s { "Api::V1::ClassName" }
          end
        end


        describe "#nodoc?" do
          let(:default_config) { { nodoc: nodoc } }

          context "when nodoc in default" do
            let(:nodoc) { true }

            it "is true" do
              expect(subject.nodoc?).to eq true
            end
          end

          context "when not nodoc in default" do
            it "is false" do
              expect(subject.nodoc?).to eq false
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


      describe "configuration helpers" do
        describe "default_configuration" do
          xit "does something"
        end


        describe "#contextual_documentation" do
          xit "does something"
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
          instance = described_class.new(
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

          instance = described_class.new(
            filename_link_pattern: "controllers/{{name}}_controller.{{extension}}.foo",
            name: 'abc'
          )

          stub(instance).extension { "xyz" }

          expect(instance.suggested_filename_link(:xyz)).to eq "controllers/abc_controller.xyz.foo"
        end
      end


      it_behaves_like "formattable"
    end
  end
end
