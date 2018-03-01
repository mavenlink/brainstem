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
                  dont_allow(instance).format_brainstem_keys!
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
              it "formats title, brainstem_keys, description, conditionals, fields, filters, sort_orders, and associations" do
                any_instance_of(described_class) do |instance|
                  mock(instance).format_title!
                  mock(instance).format_brainstem_keys!
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
            let(:lorem) { "lorem ipsum dolor sit amet" }

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


            describe "#format_brainstem_keys!" do
              before do
                stub(presenter).brainstem_keys { [ "sprockets", "widgets" ] }
              end

              it "outputs it" do
                subject.send(:format_brainstem_keys!)
                expect(subject.output).to include "Top-level key: `sprockets` / `widgets`"
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
              let(:presenter_class) do
                Class.new(Brainstem::Presenter) do
                  presents Workspace
                end
              end
              let(:presenter) { Presenter.new(Object.new, const: presenter_class, target_class: 'Workspace') }
              let(:conditionals) { {} }

              before do
                stub(presenter).conditionals { conditionals }
              end

              it "outputs a header" do
                presenter_class.fields do
                  field :name, :string
                end
                subject.send(:format_fields!)

                expect(subject.output).to include "Fields"
              end

              context "with fields present" do
                context "branch node" do
                  context "with single branch" do
                    before do
                      presenter_class.fields do
                        fields :sprockets do
                          field :sprocket_name, :string, via: :name, info: "whatever"
                        end
                      end

                      subject.send(:format_fields!)
                    end

                    it "outputs the name of the branch as a list item" do
                      expect(subject.output.scan(/\n-/).count).to eq 1
                      expect(subject.output.scan(/\n    -/).count).to eq 1
                      expect(subject.output.scan(/\n        -/).count).to eq 1
                    end

                    it "outputs the child nodes as sub-list items" do
                      expect(subject.output).to include("\n- `sprockets` (`Hash`)\n    - `sprocket_name`")
                    end
                  end

                  context "with sub-branch" do
                    before do
                      presenter_class.fields do
                        fields :sprockets do
                          fields :sub_sprocket do
                            field :sprocket_name, :string, via: :name, info: "whatever"
                          end
                        end
                      end

                      subject.send(:format_fields!)
                    end

                    it "outputs the name of sub-branches as a sub-list item" do
                      expect(subject.output.scan(/\n-/).count).to eq 1
                      expect(subject.output.scan(/\n    -/).count).to eq 1
                      expect(subject.output.scan(/\n        -/).count).to eq 1
                      expect(subject.output.scan(/\n            -/).count).to eq 1
                    end

                    it "outputs the child nodes as sub-list items" do
                      expect(subject.output).to \
                        include("\n- `sprockets` (`Hash`)\n    - `sub_sprocket` (`Hash`)\n        - `sprocket_name`")
                    end
                  end

                  context "when branch has properties" do
                    let(:conditionals) do
                      {
                        :it_is_a_friday => OpenStruct.new(
                          description: "it is a friday",
                          name: :it_is_a_friday,
                          type: :request,
                          options: {}
                        )
                      }
                    end

                    before do
                      presenter_class.fields do
                        fields :sprockets, :array, info: "parent", if: :it_is_a_friday do
                          field :sprocket_name, :string, via: :name, info: "whatever"
                        end
                      end

                      subject.send(:format_fields!)
                    end

                    it "outputs the name of the branch as a list item" do
                      expect(subject.output.scan(/\n-/).count).to eq 1
                      expect(subject.output.scan(/\n    -/).count).to eq 3
                      expect(subject.output.scan(/\n        -/).count).to eq 2
                    end

                    it "outputs the parent node with its properties" do
                      result = subject.output

                      expect(result).to include("##### Fields\n\n")
                      expect(result).to include("- `sprockets` (`Array`)\n")
                      expect(result).to include("    - parent\n")
                      expect(result).to include("    - visible when it is a friday\n")
                      expect(result).to include("    - `sprocket_name` (`String`)\n")
                      expect(result).to include("        - whatever\n")
                      expect(result).to include("        - visible when it is a friday\n\n\n\n")
                    end
                  end
                end

                context "leaf node" do
                  before do
                    presenter_class.fields do
                      field :sprocket_name, :string, via: :name
                    end

                    subject.send(:format_fields!)
                  end

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
                        before do
                          presenter_class.fields do
                            field :sprocket_name, :string,
                              info: "lorem ipsum dolor sit amet",
                              optional: true,
                              via: :name
                          end

                          subject.send(:format_fields!)
                        end

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
                        before do
                          presenter_class.fields do
                            field :sprocket_name, :string, info: "lorem ipsum dolor sit amet"
                          end

                          subject.send(:format_fields!)
                        end

                        it "outputs the description" do
                          expect(subject.output).to include "    - #{lorem}"
                        end
                      end

                      context "when absent" do
                        before do
                          presenter_class.fields do
                            field :sprocket_name, :string
                          end

                          subject.send(:format_fields!)
                        end

                        it "does not include the description" do
                          expect(subject.output).not_to include "    -"
                        end
                      end
                    end

                    describe "when field has an item type" do
                      before do
                        presenter_class.fields do
                          field :sprocket_ids, :array, item_type: :integer
                        end

                        subject.send(:format_fields!)
                      end

                      it "outputs each field's type along with the sub item type" do
                        expect(subject.output).to include "`sprocket_ids` (`Array<Integer>`)"
                      end
                    end
                  end


                  context "if it is conditional" do
                    before do
                      presenter_class.fields do
                        field :sprocket_name, :string, if: :it_is_a_friday
                      end

                      subject.send(:format_fields!)
                    end

                    context "if nodoc" do
                      let(:conditionals) { {
                        :it_is_a_friday => OpenStruct.new(
                          description: nil,
                          name: :it_is_a_friday,
                          type: :request,
                          options: { nodoc: true }
                        )
                      } }

                      it "does not include the conditional" do
                        expect(subject.output).not_to include "visible when"
                      end
                    end

                    context "if not nodoc" do
                      context "if the conditional has a description" do
                        let(:conditionals) { {
                          :it_is_a_friday => OpenStruct.new(
                            description: "it is a friday",
                            name: :it_is_a_friday,
                            type: :request,
                            options: {},
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
                            type: :request,
                            options: {},
                          )
                        } }

                        it "does not include the conditional" do
                          expect(subject.output).not_to include "visible when"
                        end
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

              context "when has filters" do
                let(:valid_filters) {
                  {
                    "published" => {
                      value: Proc.new { nil },
                      info: "limits to published"
                    }
                  }
                }

                it "outputs a header" do
                  expect(subject.output).to include "Filters"
                end

                it "lists them" do
                  expect(subject.output.scan(/\n-/).count).to eq 1
                  expect(subject.output).to include "`published`"
                  expect(subject.output).to include "    - limits to published"
                end
              end

              context "when no filters" do
                it "says nothing" do
                  expect(subject.output).to_not include "Filters"
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
                "created_at" => {
                  value: "sprockets.created_at"
                },
                "alphabetical" => {
                  value: "sprockets.name",
                  info: "it sorts by name"
                },
              } }

              before do
                subject.send(:format_sort_orders!)
              end

              context "when has sort orders defined" do
                it "outputs a header" do
                  expect(subject.output).to include "Sort Orders"
                end

                it "lists the sort orders with the default first" do
                  expect(subject.output.scan(/\n-/).count).to eq 2
                  expect(subject.output).to match /alphabetical.*created_at/m
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

                it "says nothing" do
                  expect(subject.output).to_not include "Sort Orders"
                end
              end
            end


            describe "format_associations!" do
              let(:associations) { {} }
              let(:link) { nil }

              before do
                stub(presenter).valid_associations { associations }
                stub(presenter).link_for_association(anything) { link }
                subject.send(:format_associations!)
              end

              context "when has associations" do
                let(:associations) {
                  {
                    "widgets" => OpenStruct.new(
                      name: "widgets",
                      description: "these are some widgets you might find relevant",
                      target_class: "Widget"
                    )
                  }
                }

                it "outputs a header" do
                  expect(subject.output).to include "Associations"
                end

                context "when has static target class" do
                  let(:link) { "./path" }

                  it "links them" do
                    expect(subject.output).to include "[Widget](./path)"
                  end
                end

                context "when has polymorphic target class or presenter was not found" do
                  let(:link) { nil }

                  it "lists them" do
                    expect(subject.output).to include "`widgets`"
                  end

                  it "does not render a link" do
                    expect(subject.output).to_not include "[Widget]"
                  end
                end

                describe "description" do
                  context "when present" do
                    it "lists it" do
                      expect(subject.output).to include "these are some widgets"
                    end
                  end
                end

                describe "restrict_to_only" do
                  context "when present and true" do
                    let(:associations) {
                      {
                        "widgets" => OpenStruct.new(
                          name: "widgets",
                          description: "these are some widgets you might find relevant",
                          options: { restrict_to_only: true }
                        )
                      }
                    }

                    it "lists it" do
                      expect(subject.output).to include "Restricted to queries using"
                    end

                    it "adds a period at the end of the description if there is none" do
                      expect(subject.output).to include "you might find relevant.  Restricted to queries using"
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
                      expect(subject.output).not_to include "Restricted to queries using"
                    end
                  end
                end
              end

              context "when no associations" do
                it "says nothing" do
                  expect(subject.output).to_not include "Associations"
                end
              end
            end
          end
        end
      end
    end
  end
end
