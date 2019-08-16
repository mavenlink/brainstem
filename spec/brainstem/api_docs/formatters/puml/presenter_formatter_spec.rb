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
            it "outputs the target class as the class name" do
              expect(subject).to match(/class Workspace {\n.*}/)
            end

            context "when nodoc" do
              let(:presenter) { OpenStruct.new(nodoc?: true) }

              it "returns an empty string" do
                expect(subject).to eq("")
              end
            end

            describe "formatting fields" do
              let(:target_class) { 'User' }

              before do
                presenter_class.fields do
                  field :name, :string
                  field :creator_id, :integer
                  field :archived, :boolean
                end
              end

              it "adds attribues to the output alphabetically" do
                expect(subject).to eq(<<~PUML)
                  class User {
                  boolean archived
                  integer creator_id
                  string name
                  }
                PUML
              end
            end

            describe "when associations are defined" do
              let(:target_class) { 'User' }

              before do
                presenter_class.fields do
                  field :name, :string
                end
              end

              it "adds a has_one association to the output" do
                presenter_class.associations do
                  association :cheese, Cheese, type: :has_one
                end

                expect(subject).to eq(<<~PUML)
                  class User {
                  string name
                  }
                  User o-- "1" Cheese : cheese_id
                PUML
              end

              it "adds a has_many association to the output" do
                presenter_class.associations do
                  association :posts, Post, type: :has_many
                  association :tasks, Task, type: :has_many, response_key: :task_ids
                end

                expect(subject).to eq(<<~PUML)
                  class User {
                  string name
                  }
                  User *-- "n" Post : post_ids
                  User *-- "n" Task : task_ids
                PUML
              end

              context "when associations are polymorphic" do
                before do
                  presenter_class.associations do
                    association :food, :polymorphic, type: :has_one, polymorphic_classes: [Cheese]
                    association :entities, :polymorphic, type: :has_many, polymorphic_classes: [Post, Task]
                    association :objects, :polymorphic, type: :has_many
                  end
                end

                it "adds an association for every polymorphic class to the output" do
                  expect(subject).to eq(<<~PUML)
                  class User {
                  string name
                  }
                  User o-- "1" Cheese : food
                  User *-- "n" Post : entities
                  User *-- "n" Task : entities
                  PUML
                end
              end
            end
          end
        end
      end
    end
  end
end
