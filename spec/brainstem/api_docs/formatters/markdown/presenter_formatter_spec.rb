require 'spec_helper'
require 'brainstem/api_docs/formatters/markdown/presenter_formatter'
require 'brainstem/api_docs/presenter'

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        describe PresenterFormatter do
          let(:presenter_args)       { {} }
          let(:extra_presenter_args) { {} }
          let(:presenter)            { Presenter.new(presenter_args.merge(extra_presenter_args)) }
          let(:nodoc)                { false }

          subject { described_class.new(presenter) }

          describe "#call" do
            before do
              stub(presenter).nodoc? { nodoc }
            end

            context "when nodoc" do
              let(:nodoc) { true }

              it "returns an empty output" do
                any_instance_of(described_class) do |instance|
                  dont_allow(instance).format_title!
                  dont_allow(instance).format_brainstem_key!
                  dont_allow(instance).format_description!
                  dont_allow(instance).format_fields!
                  dont_allow(instance).format_filters!
                  dont_allow(instance).format_sort_orders!
                  dont_allow(instance).format_associations!
                end

                expect(subject.call).to eq ""
              end
            end

            context "when not nodoc" do
              it "formats title, brainstem_key, description, conditionals, fields, filters, sort_orders, and associations" do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_title!
                  mock(instance).format_brainstem_key!
                  mock(instance).format_description!
                  mock(instance).format_fields!
                  mock(instance).format_filters!
                  mock(instance).format_sort_orders!
                  mock(instance).format_associations!
                end

                subject.call
              end
            end
          end


          describe "formatting" do
            let(:lorem)               { "lorem ipsum dolor sit amet" }

            describe "#format_title!" do
              context "with title" do
                it "prints it as an h4" do
                  stub(presenter).title { lorem }
                  mock(subject).md_h4(lorem) { lorem }
                  subject.send(:format_title!)
                  expect(subject.output).to eq lorem
                end
              end
            end


            describe "#format_brainstem_key!" do
              before do
                stub(presenter).brainstem_key { "widgets" }
              end

              it "outputs it" do
                subject.send(:format_brainstem_key!)
                expect(subject.output).to include "Top-level key: `widgets`"
              end
            end


            describe "#format_description!" do
              context "when present" do
                before do
                  stub(presenter).description { lorem }
                end

                it "prints it as a p" do
                  mock(subject).md_p(lorem) { lorem }
                  subject.send(:format_description!)
                  expect(subject.output).to eq lorem
                end
              end

              context "when absent" do
                before do
                  stub(presenter).description { "" }
                end

                it "prints nothing" do
                  dont_allow(subject).md_p
                  subject.send(:format_description!)
                  expect(subject.output).to eq ""
                end
              end
            end


            describe "#format_fields!" do
              let(:valid_fields) { {} }
              let(:conditionals) { {} }
              let(:optional)     { false }

              let(:sprocket_name_long) { OpenStruct.new(
                name:        :sprocket_name,
                description: lorem,
                options:     { via: :name },
                type:        :string
              ) }

              let(:sprocket_name_short) { OpenStruct.new(
                name:    :sprocket_name,
                type:    :string,
                options: { }
              ) }

              before do
                stub(sprocket_name_long).optional?  { optional }
                stub(sprocket_name_short).optional? { optional }
                stub(presenter).conditionals        { conditionals }
                stub(presenter).valid_fields        { valid_fields }
                subject.send(:format_fields!)
              end

              it "outputs a header" do
                expect(subject.output).to include "Fields"
              end

              context "with fields present" do
                context "branch node" do
                  context "with single branch" do
                    let(:valid_fields) { { sprockets: { name: sprocket_name_long } } }

                    it "outputs the name of the branch as a list item" do
                      expect(subject.output.scan(/\n-/).count).to eq 1
                      expect(subject.output.scan(/\n    -/).count).to eq 1
                      expect(subject.output.scan(/\n        -/).count).to eq 1
                    end

                    it "outputs the child nodes as sub-list items" do
                      expect(subject.output).to \
                        include("\n- `sprockets`\n    - `sprocket_name`")
                    end
                  end

                  context "with sub-branch" do
                    let(:valid_fields) { { sprockets: { sub_sprocket: { name: sprocket_name_long } } } }

                    it "outputs the name of sub-branches as a sub-list item" do
                      expect(subject.output.scan(/\n-/).count).to eq 1
                      expect(subject.output.scan(/\n    -/).count).to eq 1
                      expect(subject.output.scan(/\n        -/).count).to eq 1
                      expect(subject.output.scan(/\n            -/).count).to eq 1
                    end

                    it "outputs the child nodes as sub-list items" do
                      expect(subject.output).to \
                        include("\n- `sprockets`\n    - `sub_sprocket`\n        - `sprocket_name`")
                    end
                  end
                end

                context "leaf node" do
                  let(:valid_fields) { { sprocket_name: sprocket_name_long } }

                  context "if it is not conditional" do
                    it "outputs each field as a list item" do
                      expect(subject.output.scan(/\n-/).count).to eq 1
                    end

                    it "outputs each field's name" do
                      expect(subject.output).to include "sprocket_name"
                    end

                    it "outputs each field's type" do
                      expect(subject.output).to include "`sprocket_name` (`String`)"
                    end

                    describe "optional" do
                      context "when true" do
                        let(:optional) { true }

                        it "says so" do
                          expect(subject.output).to include "only returned when requested"
                        end

                      end

                      context "when false" do
                        it "says nothing" do
                          expect(subject.output).not_to include "Only returned when requested"
                        end
                      end
                    end

                    describe "description" do
                      context "when present" do
                        it "outputs the description" do
                          expect(subject.output).to include "    - #{lorem}"
                        end
                      end

                      context "when absent" do
                        let(:valid_fields) { { sprocket_name: sprocket_name_short } }

                        it "does not include the description" do
                          expect(subject.output).not_to include "    -"
                        end
                      end
                    end
                  end


                  context "if it is conditional" do
                    let(:sprocket_name_long) { OpenStruct.new(
                      name: :sprocket_name,
                      description: lorem,
                      options: { via: :name, if: [:it_is_a_friday] },
                      type: :string
                    ) }

                    context "if the conditional has a description" do
                      let(:conditionals) { {
                        :it_is_a_friday => OpenStruct.new(
                          description: "it is a friday",
                          name: :it_is_a_friday,
                          type: :request
                        )
                      } }

                      it "includes the conditional" do
                        expect(subject.output).to include "\n    - visible when it is a friday"
                      end
                    end

                    context "if the condition doesn't have a description" do
                      let(:conditionals) { {
                        :it_is_a_friday => OpenStruct.new(
                          description: nil,
                          name: :it_is_a_friday,
                          type: :request
                        )
                      } }

                      it "does not include the conditional" do
                        expect(subject.output).not_to include "visible when"
                      end
                    end
                  end
                end
              end

              context "with no fields" do
                it "outputs that no fields were listed" do
                  subject.send(:format_fields!)
                  expect(subject.output).to include "No fields were listed"
                end
              end
            end


            describe "#format_filters!" do
              let(:valid_filters) { {} }

              before do
                stub(presenter).valid_filters { valid_filters }
                subject.send(:format_filters!)
              end

              it "outputs a header" do
                expect(subject.output).to include "Filters"
              end

              context "when has filters" do
                let(:valid_filters) {
                  {
                    "published" => {
                      value: Proc.new { nil },
                      info: "limits to published"
                    }
                  }
                }

                it "lists them" do
                  expect(subject.output.scan(/\n-/).count).to eq 1
                  expect(subject.output).to include "`published`"
                  expect(subject.output).to include "    - limits to published"
                end
              end

              context "when no filters" do
                it "says there are none" do
                  expect(subject.output).to include "No filters were listed"
                end
              end
            end


            describe "format_sort_orders!" do
              before do
                stub(presenter).valid_sort_orders { sort_orders }
                stub(presenter).default_sort_field { "alphabetical" }
                stub(presenter).default_sort_direction { "asc" }
              end

              let(:sort_orders) { {
                "alphabetical" => {
                  value: "sprockets.name",
                  info: "it sorts by name"
                },

                "created_at" => {
                  value: "sprockets.created_at"
                },
              } }

              before do
                subject.send(:format_sort_orders!)
              end

              it "outputs a header" do
                expect(subject.output).to include "Sort Orders"
              end

              context "when has sort orders defined" do
                it "lists the sort orders" do
                  expect(subject.output.scan(/\n-/).count).to eq 2
                  expect(subject.output).to include "`alphabetical`"
                  expect(subject.output).to include "`created_at`"
                end

                it "outputs the doc string" do
                  expect(subject.output).to include "    - it sorts by name"
                end

                context "when it has a default sort order" do
                  it "inlines the default" do
                    expect(subject.output).to include "`alphabetical` - **default** (asc)"
                  end
                end
              end


              context "when has no sort orders defined" do
                let(:sort_orders) { {} }

                it "says it has none" do
                  expect(subject.output).to include "No sort orders were listed"
                end
              end
            end


            describe "format_associations!" do
              let(:associations) { {} }

              before do
                stub(presenter).valid_associations { associations }
                subject.send(:format_associations!)
              end

              it "outputs a header" do
                expect(subject.output).to include "Associations"
              end

              context "when has associations" do
                let(:associations) {
                  {
                    "widgets" => OpenStruct.new(
                      name: "widgets",
                      description: "these are some widgets you might find relevant",
                    )
                  }
                }

                it "lists them" do
                  expect(subject.output.scan(/\n-/).count).to eq 1
                  expect(subject.output).to include "`widgets`"
                end

                describe "description" do
                  context "when present" do
                    it "lists it" do
                      expect(subject.output).to include "`widgets`\n    - these are some widgets"
                    end
                  end

                  context "when absent" do
                    let(:associations) {
                      {
                        "widgets" => OpenStruct.new(
                          name: "widgets",
                          description: ""
                        )
                      }
                    }

                    it "doesn't list it" do
                      expect(subject.output).not_to include "\n    -"
                    end
                  end
                end

                describe "restrict_to_only" do
                  context "when present and true" do
                    let(:associations) {
                      {
                        "widgets" => OpenStruct.new(
                          name: "widgets",
                          options: { restrict_to_only: true }
                        )
                      }
                    }

                    it "lists it" do
                      expect(subject.output).to include "\n    - Restricted to queries"

                    end
                  end

                  context "when absent or false" do
                    let(:associations) {
                      {
                        "widgets" => OpenStruct.new(
                          name: "widgets",
                          options: { restrict_to_only: false }
                        )
                      }
                    }

                    it "doesn't show it" do
                      expect(subject.output).not_to include "\n    - Restricted to queries"
                    end
                  end
                end
              end

              context "when no associations" do
                it "says it has no associations" do
                  expect(subject.output).to include "No associations were listed"
                end
              end
            end
          end
        end
      end
    end
  end
end
