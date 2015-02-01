class WorkspacePresenter < Brainstem::Presenter
  presenter do
    preload :lead_user

    conditionals do
      model :title_is_hello, lambda { workspace.title == 'hello' }, 'visible when the title is hello'
      model :user_is_bob, lambda { current_user.username == 'bob' }, 'visible only to bob'
    end

    fields do
      field :title, :string
      field :description, :string
      field :updated_at, :datetime
      field :secret, :string, 'a secret, via secret_info',
            via: :secret_info,
            if: [:user_is_bob, :title_is_hello]

      with_options if: :user_is_bob do
        field :bob_title, :string, 'another name for the title, only for Bob',
              via: :title
      end
    end

    associations do
      association :tasks, Task, 'The Tasks in this Workspace',
                  restrict_to_only: true
      association :lead_user, User, 'The user who runs this Workspace'
      association :subtasks, Task, 'Only Tasks in this Workspace that are subtasks',
                  dynamic: lambda { |workspace| workspace.tasks.where('parent_id IS NOT NULL') },
                  brainstem_key: 'sub_tasks'
    end
  end
end

class TaskPresenter < Brainstem::Presenter
  presenter do
    fields do
      field :name, :string
    end

    associations do
      association :sub_tasks, Task
      association :other_tasks, Task, 'another copy of the sub_tasks association',
                  brainstem_key: 'other_tasks',
                  via: :sub_tasks
      association :workspace, Workspace
      association :restricted, Task, 'only available on only / show requests',
                  dynamic: lambda { task },
                  brainstem_key: 'restricted_associations'
    end
  end
end

class UserPresenter < Brainstem::Presenter
  presenter do
    fields do
      field :username, :string
    end

    associations do
      association :odd_workspaces, Workspace, 'only the odd numbered workspaces',
                  brainstem_key: 'odd_workspaces',
                  dynamic: lambda { user.workspaces.select { |workspace| workspace.id % 2 == 1 } }
    end
  end
end
  
class PostPresenter < Brainstem::Presenter
  presenter do
    fields do
      field :body, :string
    end

    associations do
      association :subject, :polymorphic
    end
  end
end
