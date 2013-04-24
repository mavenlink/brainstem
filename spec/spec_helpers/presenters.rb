class WorkspacePresenter < Brainstem::Presenter
  def present(model)
    {
      :id           => model.id,
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
      :id           => model.id,
      :name         => model.name,
      :sub_tasks    => association(:sub_tasks),
      :other_tasks  => association(:sub_tasks, :json_name => "other_tasks"),
      :workspace    => association(:workspace)
    }
  end
end

class UserPresenter < Brainstem::Presenter
  def present(model)
    {
      :id => model.id
    }
  end
end
  
class PostPresenter < Brainstem::Presenter
  def present(model)
    {
      :id => model.id,
      :body => model.body,
      :subject => association(:subject)
    }
  end
end
