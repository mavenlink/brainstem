require 'spec_helper'
require 'brainstem/concerns/controller_dsl'

module Brainstem
  module Concerns
    describe ControllerDSL do
      subject { Class.new { include Brainstem::Concerns::ControllerDSL } }

      describe ".configuration" do
        it "returns a configuration object" do
          expect(subject.configuration).to be_a Brainstem::DSL::Configuration
        end
      end

      describe ".nodoc!" do
        it "sets the config nodoc to true" do
          subject.brainstem_params do
            nodoc!
          end

          expect(subject.configuration[:_default][:nodoc]).to eq true
        end
      end

      describe ".brainstem_params" do
        it "evaluates the given block in the class context" do
          mock(subject).configuration
          subject.brainstem_params do
            self.configuration
          end
        end

        it "sets the brainstem_params_context to default when it opens" do
          context = nil
          subject.brainstem_params do
            context = brainstem_params_context
          end

          expect(context).to eq :_default
        end

        it "sets the brainstem_params_context to nil when it closes" do
          subject.brainstem_params do
            # No-op
          end

          expect(subject.brainstem_params_context).to eq nil
        end
      end


      describe ".description" do
        it "sets the description for the context" do
          subject.brainstem_params do
            description "Main description"

            actions :show do
              description "Action description"
            end
          end

          expect(subject.configuration[:_default][:description][:info]).to \
            eq "Main description"

          expect(subject.configuration[:show][:description][:info]).to \
            eq "Action description"
        end

        it "allows setting options" do
          subject.brainstem_params do
            description "Main description", nodoc: true
          end

          expect(subject.configuration[:_default][:description][:nodoc]).to \
            be true
        end
      end


      describe ".title" do
        it "sets the title for the context" do
          subject.brainstem_params do
            title "Class title"

            actions :show do
              title "Action title"
            end
          end

          expect(subject.configuration[:_default][:title][:info]).to \
            eq "Class title"

          expect(subject.configuration[:show][:title][:info]).to \
            eq "Action title"
        end

        it "allows passing options" do
          subject.brainstem_params do
            title "Class title", nodoc: true
          end

          expect(subject.configuration[:_default][:title][:nodoc]).to be true
        end
      end


      describe ".model_params" do
        before do
          stub(subject).brainstem_model_name { "widgets" }
        end

        it "evaluates the block given to it" do
          mock(subject).valid(:thing, root: "widgets")

          subject.model_params :widgets do |param|
            param.valid :thing
          end
        end

        it "merges options" do
          mock(subject).valid(:thing, root: "widgets", nodoc: true)

          subject.model_params :widgets do |param|
            param.valid :thing, nodoc: true
          end
        end
      end


      describe ".valid" do
        context "when given a name and an options hash" do
          it "appends to the valid params hash" do
            subject.brainstem_params do
              valid :sprocket_name,
                info: "sprockets[sprocket_name] is required"
            end

            expect(subject.configuration[:_default][:valid_params][:sprocket_name][:info]).to \
              eq "sprockets[sprocket_name] is required"
          end
        end

        context "when given a name and an options hash" do
          it "appends to the valid params hash" do
            # This is HWIA, so all keys are stringified
            data = {
              "recursive" => true,
              "info" => "sprockets[sub_sprockets] is recursive and an array"
            }

            subject.brainstem_params do
              valid :sub_sprockets, data
            end

            expect(subject.configuration[:_default][:valid_params][:sub_sprockets]).to \
              eq data
          end
        end
      end


      describe ".transform" do
        it "appends to the list of transforms" do
          subject.brainstem_params do
            transform :a_key => :another_key
          end

          expect(subject.configuration[:_default][:transforms]).to be_a Brainstem::DSL::Configuration
          expect(subject.configuration[:_default][:transforms][:a_key]).to eq(:another_key)
        end
      end


      describe ".presents" do
        context "when class given" do
          it "sets the presenter" do
            klass = Class.new
            subject.brainstem_params do
              presents klass
            end

            expect(subject.configuration[:_default][:presents][:target_class]).to \
              eq klass
          end

          it "allows options" do
            klass = Class.new
            subject.brainstem_params do
              presents klass, nodoc: true
            end

            expect(subject.configuration[:_default][:presents][:nodoc]).to be true
          end
        end

        context "when no name given" do
          it "falls back to the brainstem_model_class" do
            klass = Class.new
            mock(subject).brainstem_model_class { klass }

            subject.brainstem_params do
              presents
            end

            expect(subject.configuration[:_default][:presents][:target_class]).to \
              eq klass
          end
        end

        context "when symbol given" do
          it "raises an error" do
            expect { subject.brainstem_params { presents :thing } }.to raise_error RuntimeError
          end
        end

        context "when nil given" do
          it "is explicitly nil" do
            subject.brainstem_params do
              presents nil
            end

            expect(subject.configuration[:_default][:presents][:target_class]).to \
              eq nil
          end
        end
      end


      describe ".action_context" do
        it "changes context to a specific action" do
          context = nil
          subject.brainstem_params do
            action_context :show do
              context = brainstem_params_context
            end
          end

          expect(context).to eq :show
        end

        it "changes context back to the original context when done" do
          before_context    = nil
          inner_context     = nil
          after_context     = nil

          subject.brainstem_params do
            before_context = brainstem_params_context
            action_context :show do
              inner_context = brainstem_params_context
            end
            after_context = brainstem_params_context
          end

          expect(before_context).to eq after_context
          expect(inner_context).to eq :show
        end

        context "when that context does not exist" do
          before do
            subject.brainstem_params do
              title "My Controller"
              description "This is off the hook."
              action_context :show do
                # No-op
              end
            end
          end

          it "creates a context that inherits from the default context" do
            expect(subject.configuration.keys).to include "show"
          end

          it "does not inherit the title" do
            expect(subject.configuration[:show]).not_to have_key(:title)
          end

          it "does not inherit the description" do
            expect(subject.configuration[:show]).not_to have_key(:description)
          end
        end

        context "when that context exists" do
          it "uses the existing context" do
            subject.brainstem_params do
              action_context :show do
                valid :param_1, info: "something"
              end

              action_context :show do
                valid :param_2, info: "something else"
              end
            end

            expect(subject.configuration[:show][:valid_params].keys).to \
              eq ["param_1", "param_2"]

          end
        end
      end


      describe ".actions" do
        it "changes context to multiple actions" do
          mock(subject).action_context(is_a(Symbol)).twice

          subject.brainstem_params do
            actions [:show, :index] do
              valid :param_1, info: "something"
            end
          end
        end

        it "allows passing an array" do
          subject.brainstem_params do
            actions [:show, :index] do
              valid :param_1, info: "something"
            end
          end

          %w(index show).each do |meth|
            expect(subject.configuration[meth.to_sym][:valid_params].keys).to \
              include "param_1"
          end
        end

        it "allows passing multiple symbols" do
          subject.brainstem_params do
            actions :show, :index do
              valid :param_1, "something"
            end
          end

          %w(index show).each do |meth|
            expect(subject.configuration[meth.to_sym][:valid_params].keys).to \
              include "param_1"
          end
        end
      end


      describe "#valid_params" do
        let(:brainstem_model_name) { "widget" }

        before do
          stub(subject).brainstem_model_name { brainstem_model_name }
          stub.any_instance_of(subject).brainstem_model_name { brainstem_model_name }

          subject.brainstem_params do
            valid :unrelated_root_key,
              info: "it's unrelated."

            model_params(brainstem_model_name) do |params|
              params.valid :sprocket_parent_id,
                info: "sprockets[sprocket_parent_id] is required"
            end

            actions :show do
              model_params(brainstem_model_name) do |params|
                params.valid :sprocket_name,
                  info: "sprockets[sprocket_name] is required"
              end
            end
          end
        end

        it "evaluates any param root key with the controller constant if it is callable" do
          stub.any_instance_of(subject).action_name { "show" }

          subject.brainstem_params do
            model_params Proc.new { |k| k.arbitrary_method } do |params|
              params.valid :nested_key, info: "it's nested!"
            end
          end

          mock(subject).arbitrary_method { :widget }
          expect(subject.new.valid_params).to have_key("nested_key")
        end

        it "returns the brainstem_model_name children as a hash" do
          stub.any_instance_of(subject).action_name { "show" }

          expect(subject.new.valid_params).to eq({
            "sprocket_name" => { "info" => "sprockets[sprocket_name] is required", "root" => "widget" },
            "sprocket_parent_id" => { "info" => "sprockets[sprocket_parent_id] is required", "root" => "widget" }
          })
        end

        context "when has context for the current action" do
          before do
            stub.any_instance_of(subject).action_name { "show" }
          end

          it "returns the valid params for the current action merged with default" do
            expect(subject.new.valid_params.keys.sort).to eq ["sprocket_name", "sprocket_parent_id"]
          end
        end

        context "when has no context for the current action" do
          before do
            any_instance_of(subject) do |instance|
              stub(instance).action_name { "index" }
            end
          end

          it "falls back to the valid params for the default context" do
            expect(subject.new.valid_params.keys.sort).to eq ["sprocket_parent_id"]
          end
        end
      end


      describe "#transforms" do
        before do
          subject.brainstem_params do
            transform :parent_id => :sprocket_parent_id

            actions :show do
              transform :name => :sprocket_name
            end
          end
        end

        it "returns as a symbolized hash" do
          stub.any_instance_of(subject).action_name { "show" }

          expect(subject.new.transforms).to eq({
            :parent_id => :sprocket_parent_id,
            :name => :sprocket_name
          })
        end

        context "when has context for the current action" do
          before do
            any_instance_of(subject) do |instance|
              stub(instance).action_name { "show" }
            end
          end

          it "returns the transforms for the current action merged with default" do
            expect(subject.new.transforms.keys.sort).to eq [:name, :parent_id]
          end
        end

        context "when has no context for the current action" do
          before do
            any_instance_of(subject) do |instance|
              stub(instance).action_name { "index" }
            end
          end

          it "falls back to the valid params for the default context" do
            expect(subject.new.transforms.keys.sort).to eq [:parent_id]
          end
        end
      end


      describe "#contextual_key" do
        it "looks up the key for a given context" do
          subject.brainstem_params do
            description "blah"

            actions :show do
              description "less blah"
            end
          end

          expect(subject.new.send(:contextual_key, :show, :description)[:info]).to \
            eq "less blah"
        end

        it "returns the parent key if the given key is not found in context" do
          subject.brainstem_params do
            description "blah"
          end

          expect(subject.new.send(:contextual_key, :show, :description)[:info]).to eq "blah"
        end
      end
    end
  end
end
