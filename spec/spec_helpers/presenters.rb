class WorkspacePresenter < Brainstem::Presenter
  def present(model)
    {
      :title        => model.title,
      :description  => model.description,
      :updated_at   => model.updated_at,
      :tasks        => association(:tasks),
      :lead_user    => association(:lead_user, :json_name => "users")
    }
  end
end

class TaskPresenter < Brainstem::Presenter
  def present(model)
    {
      :name         => model.name,
      :sub_tasks    => association(:sub_tasks),
      :other_tasks  => association(:sub_tasks, :json_name => "other_tasks"),
      :workspace    => association(:workspace),
      :restricted   => association(:json_name => "restricted_association", :restrict_to_only => true) { |model| model }
    }
  end
end

class UserPresenter < Brainstem::Presenter
  def present(model)
    {
      :username => model.username,
      :odd_workspaces => association(:json_name => "odd_workspaces") { |user|
        user.workspaces.select { |workspace| workspace.id % 2 == 1 }
      }
    }
  end
end
  
class PostPresenter < Brainstem::Presenter
  def present(model)
    {
      :body => model.body,
      :subject => association(:subject)
    }
  end
end
