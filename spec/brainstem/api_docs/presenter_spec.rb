require 'spec_helper'
require 'brainstem/api_docs/presenter'

module Brainstem
  module ApiDocs
    describe Presenter do

      describe "#initialize" do
        it "yields self if given a block" do
          block = Proc.new { |s| s.presents = "bork bork" }
          expect(described_class.new(&block).presents).to eq "bork bork"
        end
      end


      describe "configured fields" do
        let(:lorem) { "lorem ipsum dolor sit amet" }
        let(:const) { Object.new }
        let(:config) { {} }
        let(:nodoc) { false }

        subject { described_class.new(const: const) }

        before do
          stub(const) do |constant|
            constant.configuration { config }
            constant.to_s { "Namespaced::ClassName" }
          end
        end


        describe "#nodoc?" do
          let(:config) { { nodoc: nodoc } }

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
          let(:config) { { title: { info: lorem, nodoc: nodoc } } }

          context "when nodoc" do
            let(:nodoc) { true }

            it "uses the last portion of the presenter's class" do
              expect(subject.title).to eq "ClassName"
            end
          end

          context "when not nodoc" do
            it "uses the presenter's title" do
              expect(subject.title).to eq lorem
            end
          end
        end


        describe "#brainstem_key" do
          let(:config) { { brainstem_key: lorem } }

          it "retrieves from configuration" do
            expect(subject.brainstem_key).to eq lorem
          end
        end


        describe "#description" do
          context "with description" do
            let(:config) { { description: { info: lorem, nodoc: nodoc } } }

            context "when nodoc" do
              let(:nodoc) { true }

              it "returns empty" do
                expect(subject.description).to eq ""
              end
            end

            context "when not nodoc" do
              it "returns the description" do
                expect(subject.description).to eq lorem
              end
            end
          end

          context "without description" do
            it "returns empty" do
              expect(subject.description).to eq ""
            end
          end
        end


        describe "#valid_fields" do
          let(:field) { Object.new }
          before      { stub(field).options { { nodoc: nodoc } } }

          describe "leafs" do
            let(:config) { { fields: { a_field: field } } }

            context "when nodoc" do
              let(:nodoc)  { true }

              it "rejects the field" do
                expect(subject.valid_fields.count).to eq 0
              end
            end

            context "when not nodoc" do
              it "keeps the field" do
                expect(subject.valid_fields.count).to eq 1
              end
            end
          end

          describe "branches" do
            describe "single nesting" do
              let(:config) { { fields: { nesting_one: { a_field: field } } } }

              context "when all nodoc" do
                let(:nodoc)  { true }

                it "rejects the nested field" do
                  expect(subject.valid_fields.count).to eq 0
                end
              end

              context "when not all nodoc" do
                it "keeps the nested field" do
                  expect(subject.valid_fields.count).to eq 1
                end
              end

            end

            describe "double nesting" do
              let(:config) { { fields: { nesting_one: { nesting_two: { a_field: field } } } } }

              context "when all nodoc" do
                let(:nodoc)  { true }

                it "rejects the nested field" do
                  expect(subject.valid_fields.count).to eq 0
                end
              end

              context "when not all nodoc" do
                it "keeps the nested field" do
                  expect(subject.valid_fields.count).to eq 1
                end
              end

            end
          end
        end


        describe "#valid_filters" do
          xit "does something"
        end


        describe "#valid_sort_orders" do
          xit "does something"
        end


        describe "#valid_associations" do
          xit "does something"
        end


        describe "#conditionals" do
          let(:config) { { conditionals: { thing: :other_thing } } }

          it "retrieves from configuration" do
            expect(subject.conditionals).to eq({ thing: :other_thing })
          end
        end

        describe "#default_sort_order" do
          let(:config) { { default_sort_order: "alphabetical:asc" } }

          it "retrieves from configuration" do
            expect(subject.default_sort_order).to eq "alphabetical:asc"
          end
        end


        describe "#default_sort_field" do
          context "when has default sort order" do
            let(:config) { { default_sort_order: "alphabetical:asc" } }

            it "returns the first component" do
              expect(subject.default_sort_field).to eq "alphabetical"
            end
          end

          context "when no default sort order" do
            it "returns nil" do
              expect(subject.default_sort_field).to be_nil
            end
          end
        end


        describe "#default_sort_direction" do
          context "when has default sort order" do
            let(:config) { { default_sort_order: "alphabetical:asc" } }

            it "returns the last component" do
              expect(subject.default_sort_direction).to eq "asc"
            end
          end

          context "when no default sort order" do
            it "returns nil" do
              expect(subject.default_sort_direction).to be_nil
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
        it "gsubs name and extension" do

          instance = described_class.new(
            filename_pattern: "presenters/{{name}}.{{extension}}",
            presents: 'abc'
          )

          stub(instance).extension { "xyz" }

          expect(instance.suggested_filename(:xyz)).to eq "presenters/abc.xyz"
        end
      end


      describe "#suggested_filename_link" do
        it "gsubs name and extension" do

          instance = described_class.new(
            filename_link_pattern: "presenters/{{name}}.{{extension}}.foo",
            presents: 'abc'
          )

          stub(instance).extension { "xyz" }

          expect(instance.suggested_filename_link(:xyz)).to eq "presenters/abc.xyz.foo"
        end
      end


      it_behaves_like "formattable"
    end
  end
end
