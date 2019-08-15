require 'spec_helper'
require 'brainstem/api_docs.rb'
require 'brainstem/api_docs/formatters/puml/presenter_formatter'
require 'brainstem/api_docs/presenter'

module Brainstem
  module ApiDocs
    module Formatters
      module Puml
        describe PresenterFormatter do
          let(:presenter_class) do
            Class.new(Brainstem::Presenter) do
              presents Workspace
              title "Project (Workspace)"
            end
          end

          let(:presenter) { Presenter.new(Object.new, const: presenter_class, target_class: 'Workspace') }

          subject { Brainstem::ApiDocs::FORMATTERS[:presenter][:puml].call(presenter) }

          describe "#call" do
            it "outputs the title as the class name" do
              expect(subject).to match(/class Workspace {\n.*}/)
            end

            describe "formatting fields" do
              xcontext "when no fields explicitly defined" do
                it "adds id field by default" do
                  presenter_class.fields do
                  end

                  expect(subject).to include("integer id")
                end
              end

              context "when fields are defined" do
                before do
                  presenter_class.fields do
                    field :name, :string
                    field :creator_id, :integer
                    field :archived, :boolean
                  end
                end

                it "adds the string field to the output" do
                  expect(subject).to include("string name\ninteger creator_id\nboolean archived\n")
                end
              end
            end

            context "when nodoc" do
              let(:presenter) { OpenStruct.new(nodoc?: true) }

              it "returns an empty string" do
                expect(subject).to eq("")
              end
            end
          end
        end
      end
    end
  end
end
