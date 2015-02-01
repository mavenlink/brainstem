require 'spec_helper'
require 'brainstem/concerns/presenter_dsl'

# presenter do
#   preload :lead_user
#
#   conditionals do
#     model :title_is_hello, lambda { workspace.title == 'hello' }, 'visible when the title is hello'
#     model :user_is_bob, lambda { current_user.username == 'bob' }, 'visible only to bob'
#   end
#
#   fields do
#     field :title, :string
#     field :description, :string
#     field :updated_at, :datetime
#     field :secret, :string, 'a secret, via secret_info',
#           via: :secret_info,
#           if: [:user_is_bob, :title_is_hello]
#
#     with_options if: :user_is_bob do
#       field :bob_title, :string, 'another name for the title, only for Bob',
#             via: :title
#     end
#   end
#
#   associations do
#     association :tasks, Task, 'The Tasks in this Workspace',
#                 restrict_to_only: true
#     association :lead_user, User, 'The user who runs this Workspace'
#     association :subtasks, Task, 'Only Tasks in this Workspace that are subtasks',
#                 dynamic: lambda { |workspace| workspace.tasks.where('parent_id IS NOT NULL') },
#                 brainstem_key: 'sub_tasks'
#   end
# end

describe Brainstem::Concerns::PresenterDSL do
  let(:presenter_class) do
    Class.new do
      include Brainstem::Concerns::PresenterDSL
    end
  end

  describe 'the presenter block configuration' do
    describe '#preload directive' do
      it 'builds a list of associations to preload' do
        presenter_class.presenter { preload :tasks }
        expect(presenter_class.configuration[:preloads].to_a).to eq [:tasks]
        presenter_class.presenter { preload(lead_user: { workspaces: [:lead_user, :tasks] }) }
        expect(presenter_class.configuration[:preloads].to_a).to eq [ :tasks, lead_user: { workspaces: [:lead_user, :tasks] } ]
      end

      it 'is inherited' do
        presenter_class.presenter { preload :tasks }
        subclass = Class.new(presenter_class)
        subclass.presenter { preload :lead_user }
        expect(presenter_class.configuration[:preloads].to_a).to eq [:tasks]
        expect(subclass.configuration[:preloads].to_a).to eq [:tasks, :lead_user]
      end
    end

    describe 'the conditional block' do
      before do
        presenter_class.presenter do
          conditionals do
            model      :title_is_hello, lambda { workspace.title == 'hello' }, 'visible when the title is hello'
            collection :user_is_bob, lambda { current_user.username == 'bob' }, 'visible only to bob'
          end
        end
      end

      it 'is stored in the configuration' do
        expect(presenter_class.configuration[:conditionals].keys).to eq [:title_is_hello, :user_is_bob]
        expect(presenter_class.configuration[:conditionals][:title_is_hello][:action]).to be_present
        expect(presenter_class.configuration[:conditionals][:title_is_hello][:type]).to eq :model
        expect(presenter_class.configuration[:conditionals][:title_is_hello][:description]).to eq 'visible when the title is hello'
        expect(presenter_class.configuration[:conditionals][:user_is_bob][:action]).to be_present
        expect(presenter_class.configuration[:conditionals][:user_is_bob][:type]).to eq :collection
        expect(presenter_class.configuration[:conditionals][:user_is_bob][:description]).to eq 'visible only to bob'
      end

      it 'is inherited and overridable' do
        subclass = Class.new(presenter_class)
        subclass.presenter do
          conditionals do
            model :silly_conditional, lambda { rand > 0.5 }, 'visible half the time'
            model :title_is_hello, lambda { workspace.title == 'HELLO' }, 'visible when the title is hello (in all caps)'
          end
        end
        expect(presenter_class.configuration[:conditionals].keys).to eq [:title_is_hello, :user_is_bob]
        expect(subclass.configuration[:conditionals].keys).to eq [:title_is_hello, :user_is_bob, :silly_conditional]
        expect(presenter_class.configuration[:conditionals][:title_is_hello][:description]).to eq "visible when the title is hello"
        expect(subclass.configuration[:conditionals][:title_is_hello][:description]).to eq "visible when the title is hello (in all caps)"
      end
    end

    describe 'the fields block' do
      before do
        presenter_class.presenter do
          fields do
            field :updated_at, :datetime
            field :secret, :string,
                  via: :secret_info,
                  if: [:user_is_bob, :title_is_hello]

            with_options if: :user_is_bob do
              field :bob_title, :string, 'another name for the title, only for Bob',
                    via: :title
            end
          end
        end
      end

      it 'is stored in the configuration' do
        expect(presenter_class.configuration[:fields].keys).to match_array [:updated_at, :secret, :bob_title]
        expect(presenter_class.configuration[:fields][:updated_at][:type]).to eq :datetime
        expect(presenter_class.configuration[:fields][:updated_at][:description]).to be_nil
        expect(presenter_class.configuration[:fields][:secret][:type]).to eq :string
        expect(presenter_class.configuration[:fields][:secret][:description]).to be_nil
        expect(presenter_class.configuration[:fields][:secret][:options]).to eq({ via: :secret_info, if: [:user_is_bob, :title_is_hello] })
        expect(presenter_class.configuration[:fields][:bob_title][:type]).to eq :string
        expect(presenter_class.configuration[:fields][:bob_title][:description]).to eq 'another name for the title, only for Bob'
        expect(presenter_class.configuration[:fields][:bob_title][:options]).to eq({ via: :title, if: :user_is_bob })
      end

      it 'is inherited and overridable' do
        subclass = Class.new(presenter_class)
        subclass.presenter do
          fields do
            field :title, :string
            with_options if: [:some_condition, :some_other_condition] do
              field :updated_at, :datetime, 'this time I have a description and condition'
            end
          end
        end
        expect(presenter_class.configuration[:fields].keys).to match_array [:updated_at, :secret, :bob_title]
        expect(subclass.configuration[:fields].keys).to match_array [:updated_at, :secret, :bob_title, :title]
        expect(presenter_class.configuration[:fields][:updated_at][:description]).to be_nil
        expect(presenter_class.configuration[:fields][:updated_at][:options]).to eq({})
        expect(subclass.configuration[:fields][:updated_at][:description]).to eq 'this time I have a description and condition'
        expect(subclass.configuration[:fields][:updated_at][:options]).to eq({ if: [:some_condition, :some_other_condition] })
      end
    end

    describe 'the associations block' do
      before do
        presenter_class.presenter do
          associations do
            association :tasks, Task, 'The Tasks in this Workspace',
                        restrict_to_only: true
            association :subtasks, Task, 'Only Tasks in this Workspace that are subtasks',
                        dynamic: lambda { |workspace| workspace.tasks.where('parent_id IS NOT NULL') },
                        brainstem_key: 'sub_tasks'
          end
        end
      end

      it 'is stored in the configuration' do
        expect(presenter_class.configuration[:associations].keys).to match_array [:tasks, :subtasks]
        expect(presenter_class.configuration[:associations][:tasks][:class]).to eq Task
        expect(presenter_class.configuration[:associations][:tasks][:description]).to eq 'The Tasks in this Workspace'
        expect(presenter_class.configuration[:associations][:tasks][:options]).to eq({ restrict_to_only: true })
        expect(presenter_class.configuration[:associations][:subtasks][:class]).to eq Task
        expect(presenter_class.configuration[:associations][:subtasks][:description]).to eq 'Only Tasks in this Workspace that are subtasks'
        expect(presenter_class.configuration[:associations][:subtasks][:options].keys).to eq [:dynamic, :brainstem_key]
      end

      it 'is inherited and overridable' do
        subclass = Class.new(presenter_class)
        subclass.presenter do
          associations do
            association :tasks, Task, 'The Tasks in this Workspace'
            association :lead_user, User, 'The user who runs this Workspace'
          end
        end

        expect(presenter_class.configuration[:associations].keys).to match_array [:tasks, :subtasks]
        expect(subclass.configuration[:associations].keys).to match_array [:tasks, :subtasks, :lead_user]

        expect(presenter_class.configuration[:associations][:tasks][:options]).to eq({ restrict_to_only: true })
        expect(presenter_class.configuration[:associations][:lead_user]).to be_nil

        expect(subclass.configuration[:associations][:tasks][:options]).to eq({})
        expect(subclass.configuration[:associations][:lead_user][:class]).to eq User
        expect(subclass.configuration[:associations][:lead_user][:description]).to eq 'The user who runs this Workspace'
      end
    end
  end
end
