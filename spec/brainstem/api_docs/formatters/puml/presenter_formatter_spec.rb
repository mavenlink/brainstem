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
            target_class = self.target_class
            Class.new(Brainstem::Presenter) do
              presents target_class.constantize
              title "Project (Workspace)"
            end
          end

          let(:target_class) { 'Workspace' }
          let(:presenter) { Presenter.new(Object.new, const: presenter_class, target_class: target_class) }

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
                  expect(subject).to eq(<<~PUML)
                    class User {
                    string name
                    integer creator_id
                    boolean archived
                    }
                  PUML
                end
              end

              context "when associations are defined" do
                let(:target_class) { 'User' }

                before do
                  presenter_class.fields do
                    field :name, :string
                  end

                  presenter_class.associations do
                    association :cheese, Cheese, type: :has_one
                  end
                end

                it "can add a has_one association to the output" do
                  expect(subject).to eq(<<~PUML)
                    class User {
                    string name
                    }
                    User o-- "1" Cheese
                  PUML
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
