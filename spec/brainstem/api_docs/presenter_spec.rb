require 'spec_helper'
require 'set'
require 'ostruct'
require 'brainstem/api_docs/presenter'

module Brainstem
  module ApiDocs
    describe Presenter do
      subject { described_class.new(atlas, options) }

      let(:atlas) { Object.new }
      let(:options)   { { } }

      describe "#initialize" do
        it "yields self if given a block" do
          block = Proc.new { |s| s.presents = "bork bork" }
          expect(described_class.new(atlas, &block).presents).to eq "bork bork"
        end
      end


      describe "configured fields" do
        let(:lorem)  { "lorem ipsum dolor sit amet" }
        let(:const)  { Object.new }
        let(:config) { {} }
        let(:nodoc)  { false }
        let(:options)   { { const: const } }

        subject { described_class.new(atlas, options) }

        before do
          stub(const) do |constant|
            constant.configuration { config }
            constant.to_s { "Namespaced::ClassName" }
            constant.possible_brainstem_keys { Set.new(%w(lorem ipsum)) }
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


        describe "#brainstem_keys" do
          it "retrieves from the constant, array-izes, and sorts" do
            expect(subject.brainstem_keys).to eq [ "ipsum", "lorem" ]
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
          let(:info)        { lorem }
          let(:filter)      { { info: info } }
          let(:config)      { { filters: { an_example: filter } } }

          context "when valid" do
            before do
              stub(subject).documentable_filter?(:an_example, filter) { true }
            end

            it "retrieves from configuration" do
              expect(subject.valid_filters).to eq({ an_example: filter })
            end
          end

          context "when invalid" do
            before do
              stub(subject).documentable_filter?(:an_example, filter) { false }
            end

            it "returns an empty hash" do
              expect(subject.valid_filters).to be_empty
            end
          end
        end


        describe "#documentable_filter?" do
          let(:info)   { lorem }
          let(:filter) { { nodoc: nodoc, info: info } }

          context "when nodoc" do
            let(:nodoc) { true }

            it "is false" do
              expect(subject.documentable_filter?(:filter, filter)).to eq false
            end
          end

          context "when doc" do
            context "when description present" do
              it "is true" do
                expect(subject.documentable_filter?(:filter, filter)).to eq true
              end
            end

            context "when description absent" do
              let(:info) { nil }

              context "when documenting empty filters" do
                let(:options) { { const: const, document_empty_filters: true } }

                it "is true" do
                  expect(subject.documentable_filter?(:filter, filter)).to eq true
                end
              end

              context "when not documenting empty filters" do
                let(:options) { { const: const, document_empty_filters: false } }

                it "is false" do
                  expect(subject.documentable_filter?(:filter, filter)).to eq false
                end
              end
            end
          end
        end


        describe "#valid_sort_orders" do
          let(:config) { { sort_orders: { title: { nodoc: true }, date: {} } } }

          it "returns all pairs not marked nodoc" do
            expect(subject.valid_sort_orders).to have_key(:date)
            expect(subject.valid_sort_orders).not_to have_key(:title)
          end
        end


        describe "#valid_associations" do
          let(:info)        { lorem }
          let(:association) { Object.new }
          let(:config)      { { associations: { an_example: association } } }

          context "when valid" do
            before do
              stub(subject).documentable_association?(:an_example, association) { true }
            end

            it "retrieves from configuration" do
              expect(subject.valid_associations).to eq({ an_example: association })
            end
          end

          context "when invalid" do
            before do
              stub(subject).documentable_association?(:an_example, association) { false }
            end

            it "returns an empty hash" do
              expect(subject.valid_associations).to be_empty
            end
          end
        end


        describe "#documentable_association?" do
          let(:desc)        { lorem }
          let(:association) { OpenStruct.new(options: { nodoc: nodoc }, description: desc ) }

          context "when nodoc" do
            let(:nodoc) { true }

            it "is false" do
              expect(subject.documentable_association?(:assoc, association)).to eq false
            end
          end

          context "when doc" do
            context "when description present" do
              it "is true" do
                expect(subject.documentable_association?(:assoc, association)).to eq true
              end
            end

            context "when description absent" do
              let(:desc) { nil }

              context "when documenting empty filters" do
                let(:options) { { const: const, document_empty_associations: true } }

                it "is true" do
                  expect(subject.documentable_association?(:assoc, association)).to eq true
                end
              end

              context "when not documenting empty filters" do
                let(:options) { { const: const, document_empty_associations: false } }

                it "is false" do
                  expect(subject.documentable_association?(:assoc, association)).to eq false
                end
              end
            end
          end
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

        describe "#contextual_documentation" do
          let(:config) { { title: { info: info, nodoc: nodoc } } }
          let(:info)   { lorem }

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
      end


      describe "#suggested_filename" do
        it "gsubs name and extension" do

          instance = described_class.new(atlas,
            filename_pattern: "presenters/{{name}}.{{extension}}",
            presents: 'abc'
          )

          stub(instance).extension { "xyz" }

          expect(instance.suggested_filename(:xyz)).to eq "presenters/abc.xyz"
        end
      end


      describe "#suggested_filename_link" do
        it "gsubs name and extension" do

          instance = described_class.new(atlas,
            filename_link_pattern: "presenters/{{name}}.{{extension}}.foo",
            presents: 'abc'
          )

          stub(instance).extension { "xyz" }

          expect(instance.suggested_filename_link(:xyz)).to eq "presenters/abc.xyz.foo"
        end
      end


      describe "#relative_path_to_presenter" do
        let(:presenter) {
          mock!
            .suggested_filename_link(:markdown)
            .returns("objects/sprocket_widget")
            .subject
        }

        it "returns a relative path" do
          expect(subject.relative_path_to_presenter(presenter, :markdown)).to \
            eq "sprocket_widget"
        end
      end


      describe "#link_for_association" do
        let(:presenter)    { Object.new }
        let(:target_class) { Class.new }
        let(:association)  { OpenStruct.new(target_class: target_class) }

        context "when can find presenter" do
          before do
            mock(subject).find_by_class(target_class) { presenter }
            mock(subject).relative_path_to_presenter(presenter, :markdown) { "./path" }
          end

          it "is the path" do
            expect(subject.link_for_association(association)).to eq "./path"
          end

        end

        context "when cannot find presenter" do
          before do
            mock(subject).find_by_class(target_class) { nil }
          end

          it "is nil" do
            expect(subject.link_for_association(association)).to be_nil
          end
        end
      end


      it_behaves_like "formattable"
      it_behaves_like "atlas taker"
    end
  end
end
