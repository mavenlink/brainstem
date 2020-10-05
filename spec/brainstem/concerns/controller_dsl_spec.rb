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
        it "sets the config nodoc to passed in description" do
          subject.brainstem_params do
            nodoc! "Description for why these are nodoc"
          end

          expect(subject.configuration[:_default][:nodoc]).to eq "Description for why these are nodoc"
        end

        it "sets the config nodoc to default value (true)" do
          subject.brainstem_params do
            nodoc!
          end

          expect(subject.configuration[:_default][:nodoc]).to eq true
        end
      end

      describe ".internal!" do
        it "sets the config internal to passed in description" do
          subject.brainstem_params do
            internal! "Description for why these are internal docs"
          end

          expect(subject.configuration[:_default][:internal]).to eq "Description for why these are internal docs"
        end

        it "sets the config internal to default value (true)" do
          subject.brainstem_params do
            internal!
          end

          expect(subject.configuration[:_default][:internal]).to eq true
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

      describe ".tag" do
        it "sets the tag for the context" do
          subject.brainstem_params do
            tag "TagName"
          end

          expect(subject.configuration[:_default][:tag]).to eq "TagName"
        end

        context "when used in an action" do
          it "raises and error" do
            expect {
              subject.brainstem_params do
                actions :show do
                  tag "TagName"
                end
              end
            }.to raise_error(StandardError)
          end
        end
      end

      describe ".tag_groups" do
        it "sets the tag groups" do
          subject.brainstem_params do
            tag_groups "Group Tag 1"
          end

          expect(subject.configuration[:_default][:tag_groups]).to eq ["Group Tag 1"]
        end

        it "sets the tag groups when an array is given" do
          subject.brainstem_params do
            tag_groups ["Group Tag 1", "Group Tag 2"]
          end

          expect(subject.configuration[:_default][:tag_groups]).to eq ["Group Tag 1", "Group Tag 2"]
        end

        context "when used in an action" do
          it "raises and error" do
            expect {
              subject.brainstem_params do
                actions :show do
                  tag_groups ["Group Tag 1", "Group Tag 2"]
                end
              end
            }.to raise_error(StandardError)
          end
        end
      end

      describe ".model_params" do
        let(:root_proc) { Proc.new {} }

        before do
          stub(subject).brainstem_model_name { "widgets" }
          stub(subject).format_root_name(:widgets) { root_proc }
        end

        it "evaluates the block given to it" do
          mock(subject).valid(:thing, :string, 'root' => root_proc, 'ancestors' => [root_proc])

          subject.model_params :widgets do |param|
            param.valid :thing, :string
          end
        end

        it "merges options" do
          mock(subject).valid(:thing, :integer,
            'root'      => root_proc,
            'ancestors' => [root_proc],
            'nodoc'     => true,
            'required'  => true
          )

          subject.model_params :widgets do |param|
            param.valid :thing, :integer, nodoc: true, required: true
          end
        end
      end

      describe ".valid" do
        context "when given a name and an options hash" do
          it "appends to the valid params hash" do
            subject.brainstem_params do
              valid :sprocket_ids, :array,
                info: "sprockets[sprocket_ids] is required",
                required: true,
                item_type: :integer
            end

            valid_params = subject.configuration[:_default][:valid_params]
            expect(valid_params.keys.length).to eq(1)
            expect(valid_params.keys[0]).to be_a(Proc)
            expect(valid_params.keys[0].call).to eq("sprocket_ids")

            sprocket_ids_config = valid_params[valid_params.keys[0]]
            expect(sprocket_ids_config[:info]).to eq "sprockets[sprocket_ids] is required"
            expect(sprocket_ids_config[:required]).to be_truthy
            expect(sprocket_ids_config[:type]).to eq("array")
            expect(sprocket_ids_config[:item_type]).to eq("integer")
          end
        end

        context "when given a name and an HWIA options hash" do
          it "appends to the valid params hash" do
            # This is Hash With Indifferent Access, so all keys are stringified
            data = {
              "recursive" => true,
              "info"      => "sprockets[sub_sprockets] is recursive and an array",
              "required"  => true
            }

            subject.brainstem_params do
              valid :sub_sprockets, :hash, data
            end

            valid_params = subject.configuration[:_default][:valid_params]
            expect(valid_params.keys.length).to eq(1)
            expect(valid_params.keys[0].call).to eq("sub_sprockets")
            expect(valid_params[valid_params.keys[0]]).to eq({
              "recursive" => true,
              "info"      => "sprockets[sub_sprockets] is recursive and an array",
              "required"  => true,
              "type"      => "hash",
              "nodoc"     => false
            })
          end
        end

        context "when no options are provided" do
          it "sets default options for the param" do
            subject.brainstem_params do
              valid :sprocket_name, :text
            end

            valid_params = subject.configuration[:_default][:valid_params]
            expect(valid_params.keys.length).to eq(1)
            expect(valid_params.keys[0].call).to eq("sprocket_name")

            configuration = valid_params[valid_params.keys[0]]
            expect(configuration[:nodoc]).to be_falsey
            expect(configuration[:required]).to be_falsey
            expect(configuration[:type]).to eq("text")
          end

          context "when block is specified" do
            it "defaults type to string and sets default options for the param" do
              subject.brainstem_params do
                valid :sprocket, :hash do
                  valid :title, :string
                end
              end

              valid_params = subject.configuration[:_default][:valid_params]
              expect(valid_params.keys.length).to eq(2)

              param_keys = valid_params.keys
              expect(param_keys[0].call).to eq('sprocket')
              expect(param_keys[1].call).to eq('title')

              sprocket_key = param_keys[0]
              sprocket_configuration = valid_params[sprocket_key]
              expect(sprocket_configuration[:nodoc]).to be_falsey
              expect(sprocket_configuration[:required]).to be_falsey
              expect(sprocket_configuration[:type]).to eq('hash')
              expect(sprocket_configuration[:ancestors]).to be_nil
              expect(sprocket_configuration[:root]).to be_nil

              title_configuration = valid_params[param_keys[1]]
              expect(title_configuration[:nodoc]).to be_falsey
              expect(title_configuration[:required]).to be_falsey
              expect(title_configuration[:type]).to eq('string')
              expect(title_configuration[:root]).to be_nil
              expect(title_configuration[:ancestors]).to eq([sprocket_key])
            end
          end
        end

        context "when type is hash" do
          it "adds the nested fields to valid params" do
            subject.brainstem_params do
              valid :id, :integer

              valid :info, :hash, required: true do |param|
                param.valid :title, :string, required: true
              end

              model_params :sprocket do |param|
                param.valid :data, :text
              end
            end

            valid_params = subject.configuration[:_default][:valid_params]
            expect(valid_params.keys.length).to eq(4)

            param_keys = valid_params.keys
            expect(param_keys[0].call).to eq('id')
            expect(param_keys[1].call).to eq('info')
            expect(param_keys[2].call).to eq('title')
            expect(param_keys[3].call).to eq('data')

            id_config = valid_params[param_keys[0]]
            expect(id_config[:root]).to be_nil
            expect(id_config[:ancestors]).to be_nil

            info_key = param_keys[1]
            info_config = valid_params[info_key]
            expect(info_config[:root]).to be_nil
            expect(info_config[:ancestors]).to be_nil

            info_title_config = valid_params[param_keys[2]]
            expect(info_title_config[:root]).to be_nil
            expect(info_title_config[:ancestors]).to eq([info_key])

            sprocket_data_config = valid_params[param_keys[3]]
            sprocket_data_root_key = sprocket_data_config[:root]
            expect(sprocket_data_root_key).to be_present
            expect(sprocket_data_config[:ancestors]).to eq([sprocket_data_root_key])
          end

          context "when multi nested attributes are specified" do
            it "adds the nested fields to valid params" do
              subject.brainstem_params do
                model_params :sprocket do |param|
                  param.valid :title, :string

                  param.valid :details, :hash do |nested_param|
                    nested_param.valid :category, :string

                    nested_param.valid :data, :hash do |double_nested_param|
                      double_nested_param.valid :raw_text, :string
                    end
                  end
                end
              end

              valid_params = subject.configuration[:_default][:valid_params]
              param_keys = valid_params.keys
              expect(param_keys.length).to eq(5)

              expect(param_keys[0].call).to eq('title')
              title_config = valid_params[param_keys[0]]
              root_param_key = title_config[:root]
              expect(root_param_key).to be_present
              expect(title_config[:ancestors]).to eq([root_param_key])

              expect(param_keys[1].call).to eq('details')
              details_key = param_keys[1]
              details_config = valid_params[details_key]
              expect(details_config[:root]).to eq(root_param_key)
              expect(details_config[:ancestors]).to eq([root_param_key])

              expect(param_keys[2].call).to eq('category')
              details_category_config = valid_params[param_keys[2]]
              expect(details_category_config[:root]).to be_nil
              expect(details_category_config[:ancestors]).to eq([root_param_key, details_key])

              expect(param_keys[3].call).to eq('data')
              details_data_key = param_keys[3]
              details_data_config = valid_params[details_data_key]
              expect(details_data_config[:root]).to be_nil
              expect(details_data_config[:ancestors]).to eq([root_param_key, details_key])

              expect(param_keys[4].call).to eq('raw_text')
              details_data_raw_text_config = valid_params[param_keys[4]]
              expect(details_data_raw_text_config[:root]).to be_nil
              expect(details_data_raw_text_config[:ancestors]).to eq([root_param_key, details_key, details_data_key])
            end
          end

          context "when root has no required attribute" do
            it "sets the required attribute for the parent configuration to false" do
              subject.brainstem_params do
                valid :template, :hash do |param|
                  param.valid :id, :integer
                  param.valid :title, :string
                end
              end

              valid_params = subject.configuration[:_default][:valid_params]

              template_key = valid_params.keys[0]
              expect(template_key.call).to eq('template')
              expect(valid_params[template_key][:required]).to be_falsey
            end
          end

          context "when root is nodoc" do
            it "updates the nodoc property on its nested fields to true" do
              subject.brainstem_params do
                model_params :sprocket do |param|
                  param.valid :title, :string
                  param.valid :details, :hash, nodoc: true do |param|
                    param.valid :category, :string
                    param.valid :data, :hash do |nested_param|
                      param.valid :raw_text, :string
                    end
                  end
                end
              end

              valid_params = subject.configuration[:_default][:valid_params]

              title_key = valid_params.keys[0]
              expect(title_key.call).to eq('title')
              expect(valid_params[title_key][:nodoc]).to be_falsey

              details_key = valid_params.keys[1]
              expect(details_key.call).to eq('details')
              expect(valid_params[details_key][:nodoc]).to be_truthy

              details_category_key = valid_params.keys[2]
              expect(details_category_key.call).to eq('category')
              expect(valid_params[details_category_key][:nodoc]).to be_truthy

              details_data_key = valid_params.keys[3]
              expect(details_data_key.call).to eq('data')
              expect(valid_params[details_data_key][:nodoc]).to be_truthy

              details_data_raw_text_key = valid_params.keys[4]
              expect(details_data_raw_text_key.call).to eq('raw_text')
              expect(valid_params[details_data_raw_text_key][:nodoc]).to be_truthy
            end
          end
        end

        context "when type is array" do
          it "sets the type and sub type appropriately" do
            subject.brainstem_params do
              valid :sprocket_ids, :array,
                    required: true,
                    item_type: :string
            end

            valid_params = subject.configuration[:_default][:valid_params]

            sprocket_ids_key = valid_params.keys[0]
            expect(sprocket_ids_key.call).to eq('sprocket_ids')

            sprocket_ids_config = valid_params[sprocket_ids_key]
            expect(sprocket_ids_config[:required]).to be_truthy
            expect(sprocket_ids_config[:type]).to eq('array')
            expect(sprocket_ids_config[:item_type]).to eq('string')
          end

          context "when a block is given" do
            it "sets the type and sub type appropriately" do
              subject.brainstem_params do
                valid :sprocket_tasks, :array, required: true, item_type: 'hash' do |param|
                  param.valid :task_id, :integer, required: true
                  param.valid :task_title, :string
                end
              end

              valid_params = subject.configuration[:_default][:valid_params]

              sprocket_tasks_key = valid_params.keys[0]
              expect(sprocket_tasks_key.call).to eq('sprocket_tasks')

              sprocket_tasks_config = valid_params[sprocket_tasks_key]
              expect(sprocket_tasks_config[:required]).to be_truthy
              expect(sprocket_tasks_config[:type]).to eq('array')
              expect(sprocket_tasks_config[:item_type]).to eq('hash')

              task_id_key = valid_params.keys[1]
              expect(task_id_key.call).to eq('task_id')

              task_id_config = valid_params[task_id_key]
              expect(task_id_config[:required]).to be_truthy
              expect(task_id_config[:type]).to eq('integer')
              expect(task_id_config[:root]).to be_nil
              expect(task_id_config[:ancestors]).to eq([sprocket_tasks_key])

              task_title_key = valid_params.keys[2]
              expect(task_title_key.call).to eq('task_title')

              task_title_config = valid_params[task_title_key]
              expect(task_title_config[:required]).to be_falsey
              expect(task_title_config[:type]).to eq('string')
              expect(task_title_config[:root]).to be_nil
              expect(task_title_config[:ancestors]).to eq([sprocket_tasks_key])
            end
          end
        end

        context "when the param has a dynamic key" do
          let(:dynamic_keyword) { described_class::DYNAMIC_KEY.to_s }

          it "sets the dynamic key property" do
            subject.brainstem_params do
              valid :id, :integer
              valid :_dynamic_key, :string, required: true
              valid :user_id, :integer, dynamic_key: true
            end

            valid_params = subject.configuration[:_default][:valid_params]
            expect(valid_params.keys.length).to eq(3)

            id_config_key = valid_params.keys[0]
            expect(id_config_key.call).to eq('id')
            id_config = valid_params[id_config_key]
            expect(id_config[:required]).to be_falsey
            expect(id_config[:type]).to eq("integer")

            dynamic_string_key = valid_params.keys[1]
            expect(dynamic_string_key.call).to eq(dynamic_keyword)
            dynamic_string_config = valid_params[dynamic_string_key]
            expect(dynamic_string_config[:type]).to eq("string")
            expect(dynamic_string_config[:required]).to be_truthy
            expect(dynamic_string_config[:dynamic_key]).to be_truthy

            dynamic_user_id_key = valid_params.keys[2]
            expect(dynamic_user_id_key.call).to eq('user_id')
            dynamic_user_id_config = valid_params[dynamic_user_id_key]
            expect(dynamic_user_id_config[:type]).to eq("integer")
            expect(dynamic_user_id_config[:dynamic_key]).to be_truthy
          end
        end
      end

      describe ".valid_dynamic_param" do
        let(:dynamic_keyword) { described_class::DYNAMIC_KEY.to_s }
        
        it "sets the correct configuration" do
          subject.brainstem_params do
            valid_dynamic_param :integer,
              info: "User ID is required",
              required: true
          end

          valid_params = subject.configuration[:_default][:valid_params]
          expect(valid_params.keys.length).to eq(1)
          expect(valid_params.keys[0]).to be_a(Proc)
          expect(valid_params.keys[0].call).to eq(dynamic_keyword)

          sprocket_ids_config = valid_params[valid_params.keys[0]]
          expect(sprocket_ids_config[:info]).to eq "User ID is required"
          expect(sprocket_ids_config[:required]).to be_truthy
          expect(sprocket_ids_config[:type]).to eq("integer")
          expect(sprocket_ids_config[:dynamic_key]).to be_truthy
        end

        context "when type is hash" do
          it "adds the nested fields to valid params" do
            subject.brainstem_params do
              valid :id, :integer

              valid :info, :hash, required: true do |param|
                param.valid_dynamic_param :string, required: true

                param.valid :data, :hash do |double_nested_param|
                  double_nested_param.valid_dynamic_param :string
                end
              end
            end

            valid_params = subject.configuration[:_default][:valid_params]
            param_keys = valid_params.keys
            expect(param_keys.length).to eq(5)

            expect(param_keys[0].call).to eq('id')
            id_config = valid_params[param_keys[0]]
            expect(id_config[:root]).to be_nil
            expect(id_config[:ancestors]).to be_nil

            expect(param_keys[1].call).to eq('info')
            info_key = param_keys[1]
            info_config = valid_params[info_key]
            expect(info_config[:root]).to be_nil
            expect(info_config[:ancestors]).to be_nil

            expect(param_keys[2].call).to eq(dynamic_keyword)
            dynamic_info_nested_config = valid_params[param_keys[2]]
            expect(dynamic_info_nested_config[:root]).to be_nil
            expect(dynamic_info_nested_config[:ancestors]).to eq([info_key])
            expect(dynamic_info_nested_config[:dynamic_key]).to be_truthy
            expect(dynamic_info_nested_config[:required]).to be_truthy

            expect(param_keys[3].call).to eq('data')
            details_data_key = param_keys[3]
            details_data_config = valid_params[details_data_key]
            expect(details_data_config[:root]).to be_nil
            expect(details_data_config[:ancestors]).to eq([info_key])

            expect(param_keys[4].call).to eq(dynamic_keyword)
            dynamic_data_nested_config = valid_params[param_keys[4]]
            expect(dynamic_data_nested_config[:root]).to be_nil
            expect(dynamic_data_nested_config[:ancestors]).to eq([info_key, details_data_key])
          end
        end

        context "when type is array" do
          it "sets the type and sub type appropriately" do
            subject.brainstem_params do
              valid :sprocket_ids, :array,
                    required: true,
                    item_type: :string
            end

            valid_params = subject.configuration[:_default][:valid_params]

            sprocket_ids_key = valid_params.keys[0]
            expect(sprocket_ids_key.call).to eq('sprocket_ids')

            sprocket_ids_config = valid_params[sprocket_ids_key]
            expect(sprocket_ids_config[:required]).to be_truthy
            expect(sprocket_ids_config[:type]).to eq('array')
            expect(sprocket_ids_config[:item_type]).to eq('string')
          end

          context "when a block is given" do
            it "sets the type and sub type appropriately" do
              subject.brainstem_params do
                valid :sprocket_tasks, :array, required: true, item_type: 'hash' do |param|
                  param.valid :task_id, :integer, required: true
                  param.valid :task_title, :string
                end
              end

              valid_params = subject.configuration[:_default][:valid_params]

              sprocket_tasks_key = valid_params.keys[0]
              expect(sprocket_tasks_key.call).to eq('sprocket_tasks')

              sprocket_tasks_config = valid_params[sprocket_tasks_key]
              expect(sprocket_tasks_config[:required]).to be_truthy
              expect(sprocket_tasks_config[:type]).to eq('array')
              expect(sprocket_tasks_config[:item_type]).to eq('hash')

              task_id_key = valid_params.keys[1]
              expect(task_id_key.call).to eq('task_id')

              task_id_config = valid_params[task_id_key]
              expect(task_id_config[:required]).to be_truthy
              expect(task_id_config[:type]).to eq('integer')
              expect(task_id_config[:root]).to be_nil
              expect(task_id_config[:ancestors]).to eq([sprocket_tasks_key])

              task_title_key = valid_params.keys[2]
              expect(task_title_key.call).to eq('task_title')

              task_title_config = valid_params[task_title_key]
              expect(task_title_config[:required]).to be_falsey
              expect(task_title_config[:type]).to eq('string')
              expect(task_title_config[:root]).to be_nil
              expect(task_title_config[:ancestors]).to eq([sprocket_tasks_key])
            end
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
                valid :param_1, :integer, info: "something"
              end

              action_context :show do
                valid :param_2, :string, info: "something else"
              end
            end

            expect(subject.configuration[:show][:valid_params].keys.map(&:call)).to \
              eq ["param_1", "param_2"]

          end
        end
      end

      describe ".actions" do
        it "changes context to multiple actions" do
          mock(subject).action_context(is_a(Symbol)).twice

          subject.brainstem_params do
            actions [:show, :index] do
              valid :param_1, :integer, info: "something"
            end
          end
        end

        it "allows passing an array" do
          subject.brainstem_params do
            actions [:show, :index] do
              valid :param_1, :string, info: "something"
            end
          end

          %w(index show).each do |meth|
            expect(subject.configuration[meth.to_sym][:valid_params].keys.map(&:call)).to \
              include "param_1"
          end
        end

        it "allows passing multiple symbols" do
          subject.brainstem_params do
            actions :show, :index do
              valid :param_1, :integer, info: "something"
            end
          end

          %w(index show).each do |meth|
            expect(subject.configuration[meth.to_sym][:valid_params].keys.map(&:call)).to \
              include "param_1"
          end
        end
      end

      describe ".response" do
        context "when block given" do
          it "sets the custom_response configuration" do
            subject.brainstem_params do
              actions :show do
                response :array do |response_param|
                  response_param.field :blah, :string
                end
              end
            end

            configuration = subject.configuration[:show][:custom_response]
            expect(configuration).to be_present
            expect(configuration[:_config]).to eq({
              type: 'array',
              item_type: 'hash',
              nodoc: false,
              required: false,
            }.with_indifferent_access)
          end

          context "when key is dynamic" do
            it "sets the custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do |response_param|
                    response_param.fields :mk, :hash do |dk|
                      dk.dynamic_key_field :string,
                        info: "I am a dynamic key field I"
                      dk.field :mk_blah, :string,
                        required: true
                    end

                    response_param.fields :mk2, :hash do |dk|
                      dk.field :_dynamic_key, :string,
                        required: true,
                        info: "dynamic key field II"
                    end

                    response_param.dynamic_key_fields :hash do |dk|
                      dk.field :user_id, :string,
                        dynamic_key: true,
                        info: "dynamic key field with dynamic_key attribute"
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              expect(configuration).to be_present
              expect(configuration[:_config]).to eq({
                type: 'hash',
                nodoc: false,
                required: false,
              }.with_indifferent_access)

              param_keys = configuration.keys
              expect(param_keys.length).to eq(8)

              mk_key = param_keys[1]
              expect(mk_key.call).to eq('mk')
              my_key_config = configuration.to_h[mk_key]
              expect(my_key_config).to eq({
                nodoc: false,
                type: 'hash',
                required: false,
              }.with_indifferent_access)

              mk_dynamic_key = param_keys[2]
              mk_dynamic_config = configuration.to_h[mk_dynamic_key]
              expect(mk_dynamic_config).to eq({
                nodoc: false,
                dynamic_key: true,
                type: 'string',
                ancestors: [mk_key],
                required: false,
                info: "I am a dynamic key field I"
              }.with_indifferent_access)

              mk_blah_key = param_keys[3]
              mk_blah_config = configuration.to_h[mk_blah_key]
              expect(mk_blah_config).to eq({
                nodoc: false,
                type: 'string',
                ancestors: [mk_key],
                required: true,
              }.with_indifferent_access)

              mk2_key = param_keys[4]
              mk2_config = configuration.to_h[mk2_key]
              expect(mk2_config).to eq({
                nodoc: false,
                type: 'hash',
                required: false,
              }.with_indifferent_access)

              mk2_dynamic_key = param_keys[5]
              mk2_dynamic_config = configuration.to_h[mk2_dynamic_key]
              expect(mk2_dynamic_config).to eq({
                nodoc: false,
                dynamic_key: true,
                type: 'string',
                ancestors: [mk2_key],
                required: true,
                info: "dynamic key field II",
              }.with_indifferent_access)

              dynamic_key = param_keys[6]
              dynamic_config = configuration.to_h[dynamic_key]
              expect(dynamic_config).to eq({
                nodoc: false,
                dynamic_key: true,
                type: 'hash',
                required: false,
              }.with_indifferent_access)

              dynamic_child_key = param_keys[7]
              dynamic_child_config = configuration.to_h[dynamic_child_key]
              expect(dynamic_child_config).to eq({
                nodoc: false,
                dynamic_key: true,
                ancestors: [dynamic_key],
                type: 'string',
                required: false,
                info: "dynamic key field with dynamic_key attribute",
              }.with_indifferent_access)
            end
          end
        end

        context "when block not given" do
          it "sets the custom_response configuration" do
            subject.brainstem_params do
              actions :show do
                response :array
              end
            end

            configuration = subject.configuration[:show][:custom_response]
            expect(configuration).to be_present
            expect(configuration[:_config]).to eq({
              type: 'array',
              item_type: 'string',
              nodoc: false,
              required: false,
            }.with_indifferent_access)
          end

          context "when response is a nested array of strings" do
            it "sets the custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :array, nested_levels: 2, item_type: :string
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              expect(configuration).to be_present
              expect(configuration[:_config]).to eq({
                type: 'array',
                item_type: 'string',
                nested_levels: 2,
                nodoc: false,
                required: false,
              }.with_indifferent_access)
            end

            context "when the nested level is less than 2" do
              it "does not return a config with a `nested_levels` key" do
                subject.brainstem_params do
                  actions :show do
                    response :array, nested_levels: 1, item_type: :string
                  end
                end

                configuration = subject.configuration[:show][:custom_response]
                expect(configuration).to be_present
                expect(configuration[:_config]).to eq({
                  type: 'array',
                  item_type: 'string',
                  nodoc: false,
                  required: false,
                }.with_indifferent_access)
              end
            end
          end
        end
      end

      describe ".fields" do
        context "when used outside of the response block" do
          it "raises an error" do
            expect {
              subject.brainstem_params do
                actions :show do
                  fields :contacts, :array do
                    field :full_name, :string
                  end
                end
              end
            }.to raise_error(StandardError)
          end
        end

        context "when used within the response block" do
          context "when type is hash" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    fields :contact, :hash do
                      field :full_name, :string
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq('contact')
              expect(configuration[param_keys[1]]).to eq({
                type: 'hash',
                nodoc: false,
                required: false,
              }.with_indifferent_access)

              expect(param_keys[2].call).to eq('full_name')
              expect(configuration[param_keys[2]]).to eq({
                type: 'string',
                nodoc: false,
                ancestors: [param_keys[1]],
                required: false,
              }.with_indifferent_access)
            end
          end

          context "when type is array" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    fields :contacts, :array do |contact|
                      contact.field :full_name, :string
                      contact.field :friends, :array, nested_levels: 3, item_type: :string
                      contact.field :enemies, :array, nested_levels: 1, item_type: :string
                      contact.fields :frenemies, :array, nested_levels: 2 do |frenemy|
                        frenemy.field :jim, :string
                      end
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              contacts_proc = param_keys[1]
              expect(contacts_proc.call).to eq('contacts')
              expect(configuration[contacts_proc]).to eq({
                type: 'array',
                item_type: 'hash',
                nodoc: false,
                required: false,
              }.with_indifferent_access)

              full_name_proc = param_keys[2]
              expect(full_name_proc.call).to eq('full_name')
              expect(configuration[full_name_proc]).to eq({
                type: 'string',
                nodoc: false,
                required: false,
                ancestors: [contacts_proc]
              }.with_indifferent_access)

              friends_proc = param_keys[3]
              expect(friends_proc.call).to eq('friends')
              expect(configuration[friends_proc]).to eq({
                type: 'array',
                item_type: 'string',
                nested_levels: 3,
                nodoc: false,
                required: false,
                ancestors: [contacts_proc]
              }.with_indifferent_access)

              enemies_proc = param_keys[4]
              expect(enemies_proc.call).to eq('enemies')
              expect(configuration[enemies_proc]).to eq({
                type: 'array',
                item_type: 'string',
                nodoc: false,
                required: false,
                ancestors: [contacts_proc]
              }.with_indifferent_access)

              frenemies_proc = param_keys[5]
              expect(frenemies_proc.call).to eq('frenemies')
              expect(configuration[frenemies_proc]).to eq({
                type: 'array',
                nested_levels: 2,
                item_type: 'hash',
                nodoc: false,
                required: false,
                ancestors: [contacts_proc]
              }.with_indifferent_access)

              jim_proc = param_keys[6]
              expect(jim_proc.call).to eq('jim')
              expect(configuration[jim_proc]).to eq({
                type: 'string',
                nodoc: false,
                required: false,
                ancestors: [contacts_proc, frenemies_proc]
              }.with_indifferent_access)
            end
          end

          context "when multi nested" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    fields :contact, :hash, nodoc: true do
                      fields :details, :hash do
                        field :full_name, :string
                      end
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq('contact')
              expect(configuration[param_keys[1]]).to eq({
                type: 'hash',
                nodoc: true,
                required: false,
              }.with_indifferent_access)

              expect(param_keys[2].call).to eq('details')
              expect(configuration[param_keys[2]]).to eq({
                type: 'hash',
                nodoc: true,
                required: false,
                ancestors: [param_keys[1]]
              }.with_indifferent_access)

              expect(param_keys[3].call).to eq('full_name')
              expect(configuration[param_keys[3]]).to eq({
                type: 'string',
                nodoc: true,
                required: false,
                ancestors: [param_keys[1], param_keys[2]]
              }.with_indifferent_access)
            end
          end
        end
      end

      describe ".dynamic_key_fields" do
        context "when used outside of the response block" do
          it "raises an error" do
            expect {
              subject.brainstem_params do
                actions :show do
                  dynamic_key_fields :array do
                    field :full_name, :string
                  end
                end
              end
            }.to raise_error(StandardError)
          end
        end

        context "when used within the response block" do
          let(:dynamic_keyword) { described_class::DYNAMIC_KEY.to_s }
          
          context "when type is hash" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    dynamic_key_fields :hash do
                      field :full_name, :string
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq(dynamic_keyword)
              expect(configuration[param_keys[1]]).to eq({
                type: 'hash',
                nodoc: false,
                required: false,
                dynamic_key: true,
              }.with_indifferent_access)

              expect(param_keys[2].call).to eq('full_name')
              expect(configuration[param_keys[2]]).to eq({
                type: 'string',
                nodoc: false,
                ancestors: [param_keys[1]],
                required: false,
              }.with_indifferent_access)
            end
          end

          context "when type is array" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    dynamic_key_fields :array do |contact|
                      contact.field :full_name, :string
                      contact.dynamic_key_fields :array, nested_levels: 2 do |frenemy|
                        frenemy.field :jim, :string
                      end
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              dynamic_parent_proc = param_keys[1]
              expect(dynamic_parent_proc.call).to eq(dynamic_keyword)
              expect(configuration[dynamic_parent_proc]).to eq({
                type: 'array',
                item_type: 'hash',
                nodoc: false,
                required: false,
                dynamic_key: true,
              }.with_indifferent_access)

              full_name_proc = param_keys[2]
              expect(full_name_proc.call).to eq('full_name')
              expect(configuration[full_name_proc]).to eq({
                type: 'string',
                nodoc: false,
                required: false,
                ancestors: [dynamic_parent_proc]
              }.with_indifferent_access)

              dynamic_nested_proc = param_keys[3]
              expect(dynamic_nested_proc.call).to eq(dynamic_keyword)
              expect(configuration[dynamic_nested_proc]).to eq({
                type: 'array',
                nested_levels: 2,
                item_type: 'hash',
                nodoc: false,
                required: false,
                ancestors: [dynamic_parent_proc],
                dynamic_key: true,
              }.with_indifferent_access)

              jim_proc = param_keys[4]
              expect(jim_proc.call).to eq('jim')
              expect(configuration[jim_proc]).to eq({
                type: 'string',
                nodoc: false,
                required: false,
                ancestors: [dynamic_parent_proc, dynamic_nested_proc]
              }.with_indifferent_access)
            end
          end
        end
      end

      describe ".field" do
        context "when used outside of the response block" do
          it "raises an error" do
            expect {
              subject.brainstem_params do
                actions :show do
                  field :full_name, :string
                end
              end
            }.to raise_error(StandardError)
          end
        end

        context "when used within the response block" do
          context "when type is array" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    field :names, :array
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq('names')
              expect(configuration[param_keys[1]]).to eq({
                type: 'array',
                item_type: 'string',
                nodoc: false,
                required: false,
              }.with_indifferent_access)
            end
          end

          context "when type is not array" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    field :full_name, :string
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq('full_name')
              expect(configuration[param_keys[1]]).to eq({
                type: 'string',
                nodoc: false,
                required: false,
              }.with_indifferent_access)
            end
          end

          context "when nested under parent field" do
            it "inherits the nodoc attribute" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    fields :contact, :hash, nodoc: true do
                      field :full_name, :string
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq('contact')
              expect(configuration[param_keys[1]]).to eq({
                type: 'hash',
                nodoc: true,
                required: false,
              }.with_indifferent_access)

              expect(param_keys[2].call).to eq('full_name')
              expect(configuration[param_keys[2]]).to eq({
                type: 'string',
                nodoc: true,
                required: false,
                ancestors: [param_keys[1]]
              }.with_indifferent_access)
            end
          end
        end
      end

      describe ".dynamic_key_field" do
        let(:dynamic_keyword) { described_class::DYNAMIC_KEY.to_s }

        context "when used outside of the response block" do
          it "raises an error" do
            expect {
              subject.brainstem_params do
                actions :show do
                  dynamic_key_field :string
                end
              end
            }.to raise_error(StandardError)
          end
        end

        context "when used within the response block" do
          context "when type is array" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    dynamic_key_field :array
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq(dynamic_keyword)
              expect(configuration[param_keys[1]]).to eq({
                type: 'array',
                item_type: 'string',
                nodoc: false,
                required: false,
                dynamic_key: true
              }.with_indifferent_access)
            end
          end

          context "when type is not array" do
            it "adds the field block to custom_response configuration" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    dynamic_key_field :string
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq(dynamic_keyword)
              expect(configuration[param_keys[1]]).to eq({
                type: 'string',
                nodoc: false,
                required: false,
                dynamic_key: true,
              }.with_indifferent_access)
            end
          end

          context "when nested under parent field" do
            it "inherits the nodoc attribute" do
              subject.brainstem_params do
                actions :show do
                  response :hash do
                    dynamic_key_fields :hash, nodoc: true do
                      dynamic_key_field :string
                    end
                  end
                end
              end

              configuration = subject.configuration[:show][:custom_response]
              param_keys = configuration.keys

              expect(param_keys[1].call).to eq(dynamic_keyword)
              expect(configuration[param_keys[1]]).to eq({
                type: 'hash',
                nodoc: true,
                required: false,
                dynamic_key: true,
              }.with_indifferent_access)

              expect(param_keys[2].call).to eq(dynamic_keyword)
              expect(configuration[param_keys[2]]).to eq({
                type: 'string',
                nodoc: true,
                required: false,
                dynamic_key: true,
                ancestors: [param_keys[1]]
              }.with_indifferent_access)
            end
          end
        end
      end

      describe ".operation_id" do
        it "sets the operation_id for the context" do
          subject.brainstem_params do
            actions :show do
              operation_id "getPetByID"
            end
          end

          expect(subject.configuration[:show][:operation_id]).to eq("getPetByID")
        end

        context "when defined on the default context" do
          it "raises an error" do
            expect {
              subject.brainstem_params do
                operation_id :blah
              end
            }.to raise_error(StandardError)
          end
        end
      end

      describe ".consumes" do
        it "sets the consumes property for the context" do
          subject.brainstem_params do
            consumes "application/xml", "application/json"

            actions :show do
              consumes ["application/x-www-form-urlencoded"]
            end
          end

          expect(subject.configuration[:_default][:consumes]).to \
            eq ["application/xml", "application/json"]

          expect(subject.configuration[:show][:consumes]).to \
            eq ["application/x-www-form-urlencoded"]
        end
      end

      describe ".produces" do
        it "sets the produces property for the context" do
          subject.brainstem_params do
            produces "application/xml"

            actions :show do
              produces ["application/x-www-form-urlencoded"]
            end
          end

          expect(subject.configuration[:_default][:produces]).to \
            eq ["application/xml"]

          expect(subject.configuration[:show][:produces]).to \
            eq ["application/x-www-form-urlencoded"]
        end
      end

      describe ".security" do
        it "sets the security configuration for the context" do
          subject.brainstem_params do
            security []

            actions :show do
              security({"petstore_auth" => [ "write:pets", "read:pets" ]})
            end
          end

          expect(subject.configuration[:_default][:security]).to eq []
          expect(subject.configuration[:show][:security]).to eq([
            { "petstore_auth" => [ "write:pets", "read:pets" ] }
          ])
        end
      end

      describe ".external_doc" do
        it "sets the external_doc for the context" do
          subject.brainstem_params do
            actions :show do
              external_doc description: 'External Doc',
                           url: 'www.blah.com'
            end
          end

          expect(subject.configuration[:show][:external_doc]).to eq(
            'description' => 'External Doc',
            'url' => 'www.blah.com'
          )
        end
      end

      describe ".schemes" do
        it "sets the schemes property for the context" do
          subject.brainstem_params do
            schemes "https"

            actions :show do
              schemes ["http"]
            end
          end

          expect(subject.configuration[:_default][:schemes]).to eq ["https"]
          expect(subject.configuration[:show][:schemes]).to eq ["http"]
        end
      end

      describe ".deprecated" do
        it "sets the deprecated property for the context" do
          subject.brainstem_params do
            actions :show do
              deprecated true
            end
          end

          expect(subject.configuration[:show][:deprecated]).to eq true
        end
      end

      describe "#valid_params_tree" do
        context "when no root is specified" do
          it "returns the field names as the top level keys" do
            stub.any_instance_of(subject).action_name { "show" }

            subject.brainstem_params do
              actions :show do
                valid :sprocket_ids, :array,
                      info: "sprockets[sprocket_ids] is required",
                      required: true,
                      item_type: :integer

                valid :widget_id, :integer,
                      info: "sprockets[widget_id] is not required"
              end
            end

            result = subject.new.valid_params_tree
            expect(result.keys).to match_array(%w(sprocket_ids widget_id))

            sprocket_ids_config = result[:sprocket_ids][:_config]
            expect(sprocket_ids_config).to eq({
              "info"      => "sprockets[sprocket_ids] is required",
              "required"  => true,
              "item_type" => "integer",
              "nodoc"     => false,
              "type"      => "array"
            })

            widget_id_config = result[:widget_id][:_config]
            expect(widget_id_config).to eq({
              "info"     => "sprockets[widget_id] is not required",
              "required" => false,
              "nodoc"    => false,
              "type"     => "integer"
            })
          end
        end

        context "when root is specified" do
          let(:brainstem_model_name) { "widget" }

          it "returns the root as a top level key" do
            stub(subject).brainstem_model_name { brainstem_model_name }
            stub.any_instance_of(subject).brainstem_model_name { brainstem_model_name }
            stub.any_instance_of(subject).action_name { "show" }

            subject.brainstem_params do
              valid :unrelated_root_key, :string,
                    info: "it's unrelated.",
                    required: true

              model_params(brainstem_model_name) do |params|
                params.valid :sprocket_parent_id, :long,
                             info: "widget[sprocket_parent_id] is not required"
              end

              actions :show do
                model_params(brainstem_model_name) do |params|
                  params.valid :sprocket_name, :string,
                               info: "widget[sprocket_name] is required",
                               required: true
                end
              end
            end

            result = subject.new.valid_params_tree
            expect(result.keys).to match_array(%w(widget unrelated_root_key))
            expect(result[:widget].keys).to match_array(%w(sprocket_parent_id sprocket_name))

            sprocket_parent_id_config = result[:widget][:sprocket_parent_id][:_config]
            expect(sprocket_parent_id_config).to eq({
              "info"     => "widget[sprocket_parent_id] is not required",
              "required" => false,
              "nodoc"    => false,
              "type"     => "long"
            })

            sprocket_name_config = result[:widget][:sprocket_name][:_config]
            expect(sprocket_name_config).to eq({
              "info"     => "widget[sprocket_name] is required",
              "required" => true,
              "nodoc"    => false,
              "type"     => "string"
            })
          end
        end

        context "when multiple fields share the same name" do
          let(:brainstem_model_name) { "widget" }

          it "retains config for both fields" do
            stub(subject).brainstem_model_name { brainstem_model_name }
            stub.any_instance_of(subject).brainstem_model_name { brainstem_model_name }
            stub.any_instance_of(subject).action_name { "update" }

            subject.brainstem_params do
              actions :update do
                valid :id, :integer,
                      info: "ID of the widget.",
                      required: true

                model_params(brainstem_model_name) do |params|
                  params.valid :id, :integer,
                               info: "widget[id] is optional"
                end
              end
            end

            result = subject.new.valid_params_tree
            expect(result.keys).to match_array(%w(widget id))
            expect(result[:widget].keys).to match_array(%w(id))

            id_param_config = result[:id][:_config]
            expect(id_param_config).to eq({
              "info"     => "ID of the widget.",
              "required" => true,
              "nodoc"    => false,
              "type"     => "integer"
            })

            nested_id_param_config = result[:widget][:id][:_config]
            expect(nested_id_param_config).to eq({
              "info"     => "widget[id] is optional",
              "required" => false,
              "nodoc"    => false,
              "type"     => "integer"
            })
          end
        end

        context "when multiple nested params are specified" do
          let(:brainstem_model_name) { "widget" }

          it "retains config for both fields" do
            stub(subject).brainstem_model_name { brainstem_model_name }
            stub.any_instance_of(subject).brainstem_model_name { brainstem_model_name }
            stub.any_instance_of(subject).action_name { "update" }

            subject.brainstem_params do
              actions :update do
                model_params(brainstem_model_name) do |params|
                  params.valid :title, :string,
                               info: "widget[title] is required",
                               required: true

                  params.valid :sprocket, :hash do |nested_params|
                    nested_params.valid :name, :string,
                                        info: "sprocket[name] is optional"
                  end
                end
              end
            end

            result = subject.new.valid_params_tree
            expect(result.keys).to match_array(%w(widget))
            expect(result[:widget].keys).to match_array(%w(title sprocket))

            title_param_config = result[:widget][:title][:_config]
            expect(title_param_config).to eq({
              "info"     => "widget[title] is required",
              "required" => true,
              "nodoc"    => false,
              "type"     => "string"
            })

            sprocket_param_config = result[:widget][:sprocket][:_config]
            expect(sprocket_param_config).to eq({
              "required" => false,
              "nodoc"    => false,
              "type"     => "hash"
            })

            sprocket_name_param_config = result[:widget][:sprocket][:name][:_config]
            expect(sprocket_name_param_config).to eq({
              "info"     => "sprocket[name] is optional",
              "required" => false,
              "nodoc"    => false,
              "type"     => "string"
            })
          end
        end
      end

      describe "#brainstem_valid_params" do
        let(:brainstem_model_name) { "widget" }

        before do
          stub(subject).brainstem_model_name { brainstem_model_name }
          stub.any_instance_of(subject).brainstem_model_name { brainstem_model_name }

          subject.brainstem_params do
            valid :unrelated_root_key, :string,
              info: "it's unrelated.",
              required: true

            model_params(brainstem_model_name) do |params|
              params.valid :sprocket_parent_id, :long,
                info: "sprockets[sprocket_parent_id] is not required"
            end

            actions :show do
              model_params(brainstem_model_name) do |params|
                params.valid :sprocket_name, :string,
                  info: "sprockets[sprocket_name] is required",
                  required: true
              end
            end
          end
        end

        it "evaluates any param root key with the controller constant if it is callable" do
          stub.any_instance_of(subject).action_name { "show" }

          subject.brainstem_params do
            model_params Proc.new { |k| k.arbitrary_method } do |params|
              params.valid :nested_key, :hash, info: "it's nested!"
            end
          end

          mock(subject).arbitrary_method { :widget }
          expect(subject.new.brainstem_valid_params).to have_key("nested_key")
        end

        it "returns the brainstem_model_name children as a hash" do
          stub.any_instance_of(subject).action_name { "show" }

          expect(subject.new.brainstem_valid_params).to eq({
            "sprocket_name" => {
              "_config" => {
                "info"     => "sprockets[sprocket_name] is required",
                "required" => true,
                "type"     => "string",
                "nodoc"    => false
              }
            },
            "sprocket_parent_id" => {
              "_config" => {
                "info"     => "sprockets[sprocket_parent_id] is not required",
                "type"     => "long",
                "nodoc"    => false,
                "required" => false
              }
            }
          })
        end

        context "when has context for the current action" do
          before do
            stub.any_instance_of(subject).action_name { "show" }
          end

          it "returns the valid params for the current action merged with default" do
            expect(subject.new.brainstem_valid_params.keys.sort).to eq ["sprocket_name", "sprocket_parent_id"]
          end
        end

        context "when has no context for the current action" do
          before do
            any_instance_of(subject) do |instance|
              stub(instance).action_name { "index" }
            end
          end

          it "falls back to the valid params for the default context" do
            expect(subject.new.brainstem_valid_params.keys.sort).to eq ["sprocket_parent_id"]
          end
        end

        context "when a valid param has the :if option" do
          before do
            any_instance_of(subject) do |instance|
              stub(instance).action_name { "show" }
              stub(instance).condition { condition_val }
            end
          end

          context "when the condition is a symbol" do
            before do
              subject.brainstem_params do
                actions :show do
                  model_params(brainstem_model_name) do |params|
                    params.valid :conditional_param, :string,
                                 if: :condition
                  end
                end
              end
            end

            context "when the condition evaluates to truthy" do
              let(:condition_val) { true }

              it "includes the param in the valid_params" do
                expect(subject.new.brainstem_valid_params).to have_key("conditional_param")
              end
            end

            context "when the condition evaluates to falsey" do
              let(:condition_val) { false }


              it "excludes the param in the valid_params" do
                expect(subject.new.brainstem_valid_params).to_not have_key("conditional_param")
              end
            end
          end

          context "when the condition is a Proc" do
            before do
              subject.brainstem_params do
                actions :show do
                  model_params(brainstem_model_name) do |params|
                    params.valid :conditional_param, :string,
                                 if: -> { condition }
                  end
                end
              end
            end

            context "when the condition evaluates to truthy" do
              let(:condition_val) { true }

              it "evaluates the proc in the context of the subject and includes the param in valid_params" do
                expect(subject.new.brainstem_valid_params).to have_key("conditional_param")
              end
            end

            context "when the condition evaluates to falsey" do
              let(:condition_val) { false }

              it "evaluates the proc in the context of the subject and excludes the param in valid_params" do
                expect(subject.new.brainstem_valid_params).to_not have_key("conditional_param")
              end
            end
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
