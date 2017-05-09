require 'spec_helper'
require 'brainstem/concerns/presenter_dsl'

# preload :lead_user
#
# brainstem_key :projects
#
# conditionals do
#   model   :title_is_hello, lambda { workspace.title == 'hello' }, info: 'visible when the title is hello'
#   request :user_is_bob, lambda { current_user.username == 'bob' }, info: 'visible only to bob'
# end
#
# fields do
#   field :title, :string
#   field :description, :string
#   field :updated_at, :datetime
#   field :dynamic_title, :string, dynamic: lambda { |model| model.title }
#   field :secret, :string, 'a secret, via secret_info',
#         via: :secret_info,
#         if: [:user_is_bob, :title_is_hello]
#
#   with_options if: :user_is_bob do
#     field :bob_title, :string,
#           info: 'another name for the title, only for Bob',
#           via: :title
#   end
#   fields :nested_permissions do
#     field :something_title, :string, via: :title
#     field :random, :number, dynamic: lambda { rand }
#   end
# end
#
# associations do
#   association :tasks, Task,
#               info: 'The Tasks in this Workspace',
#               restrict_to_only: true
#   association :lead_user, User,
#               info: 'The user who runs this Workspace'
#   association :subtasks, Task,
#               info: 'Only Tasks in this Workspace that are subtasks',
#               dynamic: lambda { |workspace| workspace.tasks.where('parent_id IS NOT NULL') }
#   association :something, :polymorphic
# end

describe Brainstem::Concerns::PresenterDSL do
  let(:presenter_class) do
    Class.new do
      include Brainstem::Concerns::PresenterDSL
    end
  end

  describe '#preload directive' do
    it 'builds a list of associations to preload' do
      presenter_class.preload :tasks
      expect(presenter_class.configuration[:preloads].to_a).to eq [:tasks]
      presenter_class.preload(lead_user: { workspaces: [:lead_user, :tasks] })
      expect(presenter_class.configuration[:preloads].to_a).to eq [ :tasks, lead_user: { workspaces: [:lead_user, :tasks] } ]
    end

    it 'is inherited' do
      presenter_class.preload :tasks
      subclass = Class.new(presenter_class)
      subclass.preload :lead_user
      expect(presenter_class.configuration[:preloads].to_a).to eq [:tasks]
      expect(subclass.configuration[:preloads].to_a).to eq [:tasks, :lead_user]
    end
  end

  describe 'the conditional block' do
    before do
      presenter_class.conditionals do
        model      :title_is_hello, lambda { |workspace| workspace.title == 'hello' }, info: 'visible when the title is hello'
        request    :user_is_bob, lambda { current_user == 'bob' }, info: 'visible only to bob'
      end
    end

    it 'is stored in the configuration' do
      expect(presenter_class.configuration[:conditionals].keys).to eq %w[title_is_hello user_is_bob]
      expect(presenter_class.configuration[:conditionals][:title_is_hello].action).to be_present
      expect(presenter_class.configuration[:conditionals][:title_is_hello].type).to eq :model
      expect(presenter_class.configuration[:conditionals][:title_is_hello].description).to eq 'visible when the title is hello'
      expect(presenter_class.configuration[:conditionals][:user_is_bob].action).to be_present
      expect(presenter_class.configuration[:conditionals][:user_is_bob].type).to eq :request
      expect(presenter_class.configuration[:conditionals][:user_is_bob].description).to eq 'visible only to bob'
    end

    it 'is inherited and overridable' do
      subclass = Class.new(presenter_class)
      subclass.conditionals do
        model :silly_conditional, lambda { rand > 0.5 }, info: 'visible half the time'
        model :title_is_hello, lambda { |workspace| workspace.title == 'HELLO' }, info: 'visible when the title is hello (in all caps)'
      end
      expect(presenter_class.configuration[:conditionals].keys).to eq %w[title_is_hello user_is_bob]
      expect(subclass.configuration[:conditionals].keys).to eq %w[title_is_hello user_is_bob silly_conditional]
      expect(presenter_class.configuration[:conditionals][:title_is_hello].description).to eq "visible when the title is hello"
      expect(subclass.configuration[:conditionals][:title_is_hello].description).to eq "visible when the title is hello (in all caps)"
    end

    context 'when options hash is a hash with indifferent access' do
      before do
        presenter_class.conditionals do
          request :user_is_jane, lambda { current_user == 'jane' }, { info: 'visible only to Jane' }.with_indifferent_access
        end
      end

      it 'is stored in the configuration correctly' do
        expect(presenter_class.configuration[:conditionals].keys).to include('user_is_jane')
        expect(presenter_class.configuration[:conditionals][:user_is_jane].action).to be_present
        expect(presenter_class.configuration[:conditionals][:user_is_jane].type).to eq :request
        expect(presenter_class.configuration[:conditionals][:user_is_jane].description).to eq 'visible only to Jane'
      end
    end

    context 'when description is specified in the deprecated format' do
      before do
        stub(ActiveSupport::Deprecation).warn.with(anything, anything)

        presenter_class.conditionals do
          model :user_is_jane, lambda { current_user == 'jane' }, 'visible only to Jane'
        end
      end

      it 'stores the correct configuration' do
        expect(presenter_class.configuration[:conditionals].keys).to include('user_is_jane')
        expect(presenter_class.configuration[:conditionals][:user_is_jane].action).to be_present
        expect(presenter_class.configuration[:conditionals][:user_is_jane].type).to eq :model
        expect(presenter_class.configuration[:conditionals][:user_is_jane].description).to eq 'visible only to Jane'
      end

      it 'adds a deprecation warning' do
        expect(ActiveSupport::Deprecation).to have_received.warn.with(anything, anything)
      end
    end
  end

  describe 'the fields block' do
    before do
      presenter_class.fields do
        field :updated_at, :datetime
        field :dynamic_title, :string, dynamic: lambda { |model| model.title }
        field :secret, :string,
              via: :secret_info,
              if: [:user_is_bob, :title_is_hello]

        with_options if: :user_is_bob do
          field :bob_title, :string,
                info: 'another name for the title, only for Bob',
                via: :title
        end
        fields :nested_permissions do
          field :something_title, :string, via: :title
          field :random, :number, dynamic: lambda { rand }
        end
      end
    end

    it 'is stored in the configuration' do
      expect(presenter_class.configuration[:fields].keys).to match_array %w[updated_at dynamic_title secret bob_title nested_permissions]
      expect(presenter_class.configuration[:fields][:updated_at].type).to eq :datetime
      expect(presenter_class.configuration[:fields][:updated_at].description).to be_nil
      expect(presenter_class.configuration[:fields][:dynamic_title].type).to eq :string
      expect(presenter_class.configuration[:fields][:dynamic_title].description).to be_nil
      expect(presenter_class.configuration[:fields][:dynamic_title].options[:dynamic]).to be_a(Proc)
      expect(presenter_class.configuration[:fields][:secret].type).to eq :string
      expect(presenter_class.configuration[:fields][:secret].description).to be_nil
      expect(presenter_class.configuration[:fields][:secret].options).to eq({ via: :secret_info, if: [:user_is_bob, :title_is_hello] })
      expect(presenter_class.configuration[:fields][:bob_title].type).to eq :string
      expect(presenter_class.configuration[:fields][:bob_title].description).to eq 'another name for the title, only for Bob'
      expect(presenter_class.configuration[:fields][:bob_title].options).to eq(
        via: :title,
        if: [:user_is_bob],
        info: 'another name for the title, only for Bob'
      )
    end

    it 'handles nesting' do
      expect(presenter_class.configuration[:fields][:nested_permissions][:something_title].type).to eq :string
      expect(presenter_class.configuration[:fields][:nested_permissions][:something_title].options[:via]).to eq :title
      expect(presenter_class.configuration[:fields][:nested_permissions][:random].options[:dynamic]).to be_a(Proc)
    end

    it 'is inherited and overridable' do
      subclass = Class.new(presenter_class)
      subclass.fields do
        field :title, :string
        with_options if: [:some_condition, :some_other_condition] do
          field :updated_at, :datetime, info: 'this time I have a description and condition'
        end
      end
      expect(presenter_class.configuration[:fields].keys).to match_array %w[updated_at dynamic_title secret bob_title nested_permissions]
      expect(subclass.configuration[:fields].keys).to match_array %w[updated_at dynamic_title secret bob_title title nested_permissions]
      expect(presenter_class.configuration[:fields][:updated_at].description).to be_nil
      expect(presenter_class.configuration[:fields][:updated_at].options).to eq({})
      expect(subclass.configuration[:fields][:updated_at].description).to eq 'this time I have a description and condition'
      expect(subclass.configuration[:fields][:updated_at].options).to eq(
        if: [:some_condition, :some_other_condition],
        info: 'this time I have a description and condition'
      )
    end

    it 'any :if options are combined and inherited using with_options' do
      presenter_class.fields do
        with_options if: :user_is_bob do
          field :bob_title, :string,
                info: 'another name for the title, only for Bob',
                via: :title,
                if: :another_condition
          field :bob_title2, :string,
                info: 'another name for the title, only for Bob',
                via: :title, if: :another_condition
        end
      end
      subclass = Class.new(presenter_class)
      subclass.fields do
        with_options if: [:user_is_bob, :more_specific] do
          field :bob_title, :string,
                info: 'another name for the title, only for Bob',
                via: :title, if: [:another_condition]
          field :bob_title2, :string,
                info: 'another name for the title, only for Bob',
                via: :title
        end
      end

      expect(presenter_class.configuration[:fields][:bob_title].options[:if]).to eq([:user_is_bob, :another_condition])
      expect(subclass.configuration[:fields][:bob_title].options[:if]).to eq([:user_is_bob, :more_specific, :another_condition])

      expect(presenter_class.configuration[:fields][:bob_title2].options[:if]).to eq([:user_is_bob, :another_condition])
      expect(subclass.configuration[:fields][:bob_title2].options[:if]).to eq([:user_is_bob, :more_specific])
    end

    it 'allows nesting to be inherited and overridden too' do
      subclass = Class.new(presenter_class)
      subclass.fields do
        fields :nested_permissions do
          field :something_title, :number, via: :title
          field :new, :string, via: :title
          fields :deeper do
            field :something, :string, via: :title
          end
        end

        fields :new_nested_permissions do
          field :something, :string, via: :title
        end
      end
      expect(presenter_class.configuration[:fields].keys).to match_array %w[updated_at dynamic_title secret bob_title nested_permissions]
      expect(subclass.configuration[:fields].keys).to match_array %w[updated_at dynamic_title secret bob_title nested_permissions new_nested_permissions]

      expect(presenter_class.configuration[:fields][:nested_permissions][:something_title].type).to eq :string
      expect(presenter_class.configuration[:fields][:nested_permissions][:random].type).to eq :number
      expect(presenter_class.configuration[:fields][:nested_permissions][:new]).to be_nil
      expect(presenter_class.configuration[:fields][:nested_permissions][:deeper]).to be_nil
      expect(presenter_class.configuration[:fields][:new_nested_permissions]).to be_nil

      expect(subclass.configuration[:fields][:nested_permissions][:something_title].type).to eq :number # changed this
      expect(subclass.configuration[:fields][:nested_permissions][:random].type).to eq :number
      expect(subclass.configuration[:fields][:nested_permissions][:new].type).to eq :string
      expect(subclass.configuration[:fields][:nested_permissions][:deeper][:something]).to be_present
      expect(subclass.configuration[:fields][:new_nested_permissions]).to be_present
    end

    context "when options is a hash with indifferent access" do
      before do
        presenter_class.fields do
          field :synced_at, :datetime, { info: "Last time the object was synced" }.with_indifferent_access
        end
      end

      it "is stored in the configuration correctly" do
        expect(presenter_class.configuration[:fields].keys).to include('synced_at')
        expect(presenter_class.configuration[:fields][:synced_at].type).to eq :datetime
        expect(presenter_class.configuration[:fields][:synced_at].description).to eq 'Last time the object was synced'
      end
    end

    context "when description is specified in the deprecated format" do
      before do
        stub(ActiveSupport::Deprecation).warn.with(anything, anything)

        presenter_class.fields do
          field :synced_at, :datetime, "Last time the object was synced"
        end
      end

      it "stores the correct configuration" do
        expect(presenter_class.configuration[:fields].keys).to include('synced_at')
        expect(presenter_class.configuration[:fields][:synced_at].type).to eq :datetime
        expect(presenter_class.configuration[:fields][:synced_at].description).to eq 'Last time the object was synced'
      end

      it 'adds a deprecation warning' do
        expect(ActiveSupport::Deprecation).to have_received.warn.with(anything, anything)
      end
    end
  end

  describe 'the associations block' do
    before do
      presenter_class.associations do
        association :tasks, Task,
                    info: 'The Tasks in this Workspace',
                    restrict_to_only: true
        association :subtasks, Task,
                    info: 'Only Tasks in this Workspace that are subtasks',
                    dynamic: lambda { |workspace| workspace.tasks.where('parent_id IS NOT NULL') }
        association :something, :polymorphic
      end
    end

    it 'is stored in the configuration' do
      expect(presenter_class.configuration[:associations].keys).to match_array %w[tasks subtasks something]
      expect(presenter_class.configuration[:associations][:tasks].target_class).to eq Task
      expect(presenter_class.configuration[:associations][:tasks].description).to eq 'The Tasks in this Workspace'
      expect(presenter_class.configuration[:associations][:tasks].options).to eq({ restrict_to_only: true, info: 'The Tasks in this Workspace' })
      expect(presenter_class.configuration[:associations][:subtasks].target_class).to eq Task
      expect(presenter_class.configuration[:associations][:subtasks].description).to eq 'Only Tasks in this Workspace that are subtasks'
      expect(presenter_class.configuration[:associations][:subtasks].options.keys).to match_array [:dynamic, :info]
      expect(presenter_class.configuration[:associations][:something].target_class).to eq :polymorphic
      expect(presenter_class.configuration[:associations][:something].description).to be_nil
    end

    it 'is inherited and overridable' do
      subclass = Class.new(presenter_class)
      subclass.associations do
        association :tasks, Task, info: 'The Tasks in this Workspace'
        association :lead_user, User, info: 'The user who runs this Workspace'
      end

      expect(presenter_class.configuration[:associations].keys).to match_array %w[tasks subtasks something]
      expect(subclass.configuration[:associations].keys).to match_array %w[tasks subtasks lead_user something]

      expect(presenter_class.configuration[:associations][:tasks].options).to eq({ restrict_to_only: true, info: 'The Tasks in this Workspace' })
      expect(presenter_class.configuration[:associations][:lead_user]).to be_nil

      expect(subclass.configuration[:associations][:tasks].options).to eq({ info: 'The Tasks in this Workspace' })
      expect(subclass.configuration[:associations][:lead_user].target_class).to eq User
      expect(subclass.configuration[:associations][:lead_user].description).to eq 'The user who runs this Workspace'
    end

    context "when options is a hash with indifferent access" do
      before do
        presenter_class.associations do
          association :something_else, :polymorphic, { info: 'The other things in this Workspace', restrict_to_only: true }.with_indifferent_access
        end
      end

      it "is stored in the configuration correctly" do
        expect(presenter_class.configuration[:associations].keys).to include('something_else')
        expect(presenter_class.configuration[:associations][:something_else].description).to eq 'The other things in this Workspace'
        expect(presenter_class.configuration[:associations][:something_else].options).to eq(
          info: 'The other things in this Workspace',
          restrict_to_only: true
        )
      end
    end

    context "when description is specified in the deprecated format" do
      before do
        stub(ActiveSupport::Deprecation).warn.with(anything, anything)

        presenter_class.associations do
          association :something_else, :polymorphic, 'The other things in this Workspace', restrict_to_only: true
        end
      end

      it "stores the correct configuration" do
        expect(presenter_class.configuration[:associations].keys).to include('something_else')
        expect(presenter_class.configuration[:associations][:something_else].description).to eq 'The other things in this Workspace'
        expect(presenter_class.configuration[:associations][:something_else].options).to eq(
          info: 'The other things in this Workspace',
          restrict_to_only: true
        )
      end

      it 'adds a deprecation warning' do
        expect(ActiveSupport::Deprecation).to have_received.warn.with(anything, anything)
      end
    end
  end

  describe ".helper" do
    let(:model) { Workspace.first }

    let(:presenter) do
      Class.new(Brainstem::Presenter) do
        helper do
          def method_in_block
            'method_in_block'
          end

          def block_to_module
            'i am in a block, but can see ' + method_in_module
          end
        end

        fields do
          field :from_module, :string, dynamic: lambda { method_in_module }
          field :from_block, :string, dynamic: lambda { method_in_block }
          field :block_to_module, :string, dynamic: lambda { block_to_module }
          field :module_to_block, :string, dynamic: lambda { module_to_block }
        end
      end
    end

    let(:sub_presenter) do
      Class.new(presenter) do
        helper do
          def method_in_block
            'overridden method_in_block'
          end
        end
      end
    end

    let(:helper_module) do
      Module.new do
        def method_in_module
          'method_in_module'
        end

        def module_to_block
          'i am in a module, but can see ' + method_in_block
        end
      end
    end

    let(:sub_helper_module) do
      Module.new do
        def method_in_module
          'overridden method_in_module'
        end
      end
    end

    it 'provides any methods from given blocks to the lambda' do
      presenter.helper helper_module
      expect(presenter.new.group_present([model]).first['from_block']).to eq 'method_in_block'
    end

    it 'provides any methods from given Modules to the lambda' do
      presenter.helper helper_module
      expect(presenter.new.group_present([model]).first['from_module']).to eq 'method_in_module'
    end

    it 'allows methods in modules and blocks to see each other' do
      presenter.helper helper_module
      expect(presenter.new.group_present([model]).first['block_to_module']).to eq 'i am in a block, but can see method_in_module'
      expect(presenter.new.group_present([model]).first['module_to_block']).to eq 'i am in a module, but can see method_in_block'
    end

    it 'merges the blocks and modules into a combined helper' do
      presenter.helper helper_module
      expect(presenter.merged_helper_class.instance_methods).to include(:method_in_module, :module_to_block, :method_in_block, :block_to_module)
    end

    it 'can be cleaned up' do
      expect(presenter.merged_helper_class.instance_methods).to include(:method_in_block)
      expect(presenter.merged_helper_class.instance_methods).to_not include(:method_in_module)
      presenter.helper helper_module
      expect(presenter.merged_helper_class.instance_methods).to include(:method_in_block, :method_in_module)
      presenter.reset!
      expect(presenter.merged_helper_class.instance_methods).to_not include(:method_in_block)
      expect(presenter.merged_helper_class.instance_methods).to_not include(:method_in_module)
    end

    it 'caches the generated class' do
      class1 = presenter.merged_helper_class
      class2 = presenter.merged_helper_class
      expect(class1).to eq class2
      presenter.helper helper_module
      class3 = presenter.merged_helper_class
      class4 = presenter.merged_helper_class
      expect(class1).not_to eq class3
      expect(class3).to eq class4
    end

    it 'is inheritable' do
      presenter.helper helper_module
      expect(sub_presenter.new.group_present([model]).first['from_block']).to eq 'overridden method_in_block'
      expect(sub_presenter.new.group_present([model]).first['from_module']).to eq 'method_in_module'
      expect(sub_presenter.new.group_present([model]).first['block_to_module']).to eq 'i am in a block, but can see method_in_module'
      expect(sub_presenter.new.group_present([model]).first['module_to_block']).to eq 'i am in a module, but can see overridden method_in_block'
      sub_presenter.helper sub_helper_module
      expect(sub_presenter.new.group_present([model]).first['from_module']).to eq 'overridden method_in_module'
      expect(sub_presenter.new.group_present([model]).first['block_to_module']).to eq 'i am in a block, but can see overridden method_in_module'
      expect(presenter.new.group_present([model]).first['from_module']).to eq 'method_in_module'
      expect(presenter.new.group_present([model]).first['block_to_module']).to eq 'i am in a block, but can see method_in_module'
    end

    it 'caches the generated classes with inheritance' do
      class1 = presenter.merged_helper_class
      class2 = sub_presenter.merged_helper_class
      expect(presenter.merged_helper_class).to eq class1
      expect(sub_presenter.merged_helper_class).to eq class2

      presenter.helper helper_module

      expect(presenter.merged_helper_class).not_to eq class1
      expect(sub_presenter.merged_helper_class).not_to eq class2
    end
  end

  describe ".filter" do
    it "creates an entry in the filters configuration" do
      presenter_class.filter(:foo, :default => true) { 1 }
      expect(presenter_class.configuration[:filters][:foo][0]).to eq({"default" => true})
      expect(presenter_class.configuration[:filters][:foo][1]).to be_a(Proc)
    end

    it "accepts names without blocks" do
      presenter_class.filter(:foo)
      expect(presenter_class.configuration[:filters][:foo][1]).to be_nil
    end
  end

  describe ".search" do
    it "creates an entry in the search configuration" do
      presenter_class.search do end
      expect(presenter_class.configuration[:search]).to be_a(Proc)
    end
  end

  describe ".brainstem_key" do
    before do
      presenter_class.brainstem_key(:foo)
    end

    it "creates an entry in the brainstem_key configuration" do
      expect(presenter_class.configuration[:brainstem_key]).to eq('foo')
    end

    it 'is inherited and overridable' do
      subclass = Class.new(presenter_class)
      expect(subclass.configuration[:brainstem_key]).to eq('foo')
      subclass.brainstem_key(:bar)
      expect(subclass.configuration[:brainstem_key]).to eq('bar')
      expect(presenter_class.configuration[:brainstem_key]).to eq('foo')
    end
  end
end
