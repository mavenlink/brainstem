class WorkspacePresenter < Brainstem::Presenter
  presents Workspace

  helper do
    def current_user
      'jane'
    end
  end

  preload :lead_user

  conditionals do
    model   :title_is_hello, lambda { |model| model.title == 'hello' }, 'visible when the title is hello'
    request :user_is_bob, lambda { current_user == 'bob' }, 'visible only to bob'
  end

  fields do
    field :title, :string
    field :description, :string
    field :updated_at, :datetime
    field :dynamic_title, :string, dynamic: lambda { |model| "title: #{model.title}" }

    fields :permissions do
      field :access_level, :integer, dynamic: lambda { 2 }
    end

    field :hello_title, :string, 'the title, when hello',
          dynamic: lambda { 'title is hello' },
          if: :title_is_hello

    field :secret, :string, 'a secret, via secret_info',
          via: :secret_info,
          if: [:user_is_bob, :title_is_hello]

    with_options if: :user_is_bob do
      field :bob_title, :string, 'another name for the title, only for Bob',
            via: :title
    end
  end

  associations do
    association :tasks, Task, 'The Tasks in this Workspace'
    association :lead_user, User, 'The user who runs this Workspace'
    # association :subtasks, Task, 'Only Tasks in this Workspace that are subtasks',
    #             dynamic: lambda { |workspace| workspace.tasks.where('parent_id IS NOT NULL') },
    #             brainstem_key: 'sub_tasks'
  end
end

class GroupPresenter < Brainstem::Presenter
  presents Group

  fields do
    field :title, :string
  end

  associations do
    association :tasks, Task, 'The Tasks in this Group'
  end
end

class TaskPresenter < Brainstem::Presenter
  presents Task

  fields do
    field :name, :string
  end

  associations do
    association :sub_tasks, Task
    association :other_tasks, Task, 'another copy of the sub_tasks association',
                via: :sub_tasks
    association :workspace, Workspace
    association :restricted, Task, 'only available on only / show requests',
                dynamic: lambda { |task| Task.last },
                restrict_to_only: true
  end
end

class UserPresenter < Brainstem::Presenter
  presents User

  fields do
    field :username, :string
  end

  associations do
    association :odd_workspaces, Workspace, 'only the odd numbered workspaces',
                dynamic: lambda { |user| user.workspaces.select { |workspace| workspace.id % 2 == 1 } }
  end
end

class PostPresenter < Brainstem::Presenter
  presents Post

  fields do
    field :body, :string
  end

  associations do
    association :subject, :polymorphic
    association :attachments, Attachments::PostAttachment
  end
end

class AttachmentPresenter < Brainstem::Presenter
  presents Attachments::TaskAttachment, Attachments::PostAttachment

  fields do
    field :filename, :string
  end

  associations do
    association :subject, :polymorphic
  end
end

# TODO: inheritance of presenters