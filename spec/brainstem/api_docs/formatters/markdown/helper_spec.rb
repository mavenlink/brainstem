require 'spec_helper'
require 'brainstem/api_docs/formatters/markdown/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        describe "Helper" do
          let(:klass) { Class.new { include Helper } }

          let(:lipsum) { "Lorem ipsum dolor sit amet, nulla primis tritani id qui. Eam elitr prodesset in, ne nec nibh elit impedit. Inani rationibus mnesarchum ei vix, at has eligendi scripserit. Vel vidit semper ea. Id ullum scaevola adversarium eum, vide brute mucius ut has." }
          let(:lipsum_split_80) { [
            "Lorem ipsum dolor sit amet, nulla primis tritani id qui. Eam elitr prodesset in,",
            "ne nec nibh elit impedit. Inani rationibus mnesarchum ei vix, at has eligendi",
            "scripserit. Vel vidit semper ea. Id ullum scaevola adversarium eum, vide brute",
            "mucius ut has."
          ] }

          subject { klass.new }

          1.upto(5) do |num|
            describe "#md_h#{num}" do
              it "renders text with #{num} # and two newlines" do
                expect(subject.send("md_h#{num}", "title")).to eq "#{"#" * num} title\n\n"
              end
            end
          end

          describe "#md_hr" do
            it "renders five dashes and two newlines" do
              expect(subject.md_hr).to eq "-----\n\n"
            end
          end


          describe "#md_p" do
            it "appends two newlines" do
              expect(subject.md_p(lipsum)).to eq(lipsum + "\n\n")
            end
          end


          describe "#md_strong" do
            it "wraps the text in asterisk pairs" do
              expect(subject.md_strong("Popeye")).to eq "**Popeye**"
            end
          end


          describe "#md_code" do
            it "renders the code between backtick blocks" do
              expect(subject.md_code('var my_var = 1;')).to eq "```\nvar my_var = 1;\n```\n\n"
            end

            it "allows specifying a language" do
              expect(subject.md_code('puts "Hi!"', 'ruby')).to eq %Q{```ruby\nputs "Hi!"\n```\n\n}
            end
          end


          describe "#md_inline_code" do
            it "renders the code between single backticks" do
              expect(subject.md_inline_code('my_var')).to eq "`my_var`"
            end
          end


          describe "#md_ul" do
            it "evaluates the block given to it in the instance's context" do
              mock(subject).md_h1('hello') { }
              subject.md_ul { md_h1("hello") }
            end

            it "appends two newlines to the end of the list" do
              expect(subject.md_ul { nil }).to eq "\n\n"
            end
          end


          describe "#md_li" do
            it "renders the text after a dash-space with a newline" do
              expect(subject.md_li("text")).to eq "- text\n"
            end

            it "allows specifying the indent" do
              expect(subject.md_li("text", 1)).to eq "    - text\n"
            end
          end


          describe "#md_a" do
            it "renders the text in a bracket and includes a link in parens" do
              expect(subject.md_a("text", "link.md")).to eq "[text](link.md)"
            end
          end


          describe "#md_inline_type" do
            it "renders the code between single backticks" do
              expect(subject.md_inline_type("string")).to eq " (`String`)"
            end

            context "when type is blank" do
              it "returns an empty string" do
                expect(subject.md_inline_type("")).to eq ""
              end
            end

            context "when item type is specified" do
              it "renders the code between single backticks" do
                expect(subject.md_inline_type("array", "integer")).to eq " (`Array<Integer>`)"
              end
            end
          end


          describe "#md_associations_table" do
            let(:presenter) { Object.new }

            before do
              stub(presenter).valid_associations { valid_associations }
            end

            context "when presenter has valid associations" do
              let(:valid_associations) {
                {
                  'association_1' => OpenStruct.new(
                    name:         'association_1',
                    target_class: 'association_1_class',
                    description:  'association_1 description'
                  ),
                  'association_2' => OpenStruct.new(
                    name:         'association_2',
                    target_class: 'association_2_class',
                    description:  'association_2 description',
                    options:      { restrict_to_only: true }
                  )
                }
              }

              it "adds them to the description" do
                result = subject.md_associations_table(presenter)

                expect(result).to include("Associations")
                expect(result).to include("Association Name | Associated Class | Description\n")
                expect(result).to include(" --------------  |  --------------  |  ----------\n")
                expect(result).to include("`association_1` | association_1_class | association_1 description\n")

                association_2_desc = "association_2 description.  Restricted to queries using the `only` parameter."
                expect(result).to include("`association_2` | association_2_class | #{association_2_desc}\n")
              end
            end

            context "when presenter has no valid associations" do
              let(:valid_associations) { {} }

              it "adds them to the description" do
                expect(subject.md_associations_table(presenter)).to eq("")
              end
            end
          end
        end
      end
    end
  end
end
