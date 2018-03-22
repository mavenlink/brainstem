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
        end
      end
    end
  end
end
