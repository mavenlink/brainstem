ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users, :force => true do |t|
    t.string :username
    t.timestamps null: true
  end

  create_table :workspaces, :force => true do |t|
    t.string :title
    t.string :description
    t.belongs_to :user
    t.timestamps null: true
  end

  create_table :tasks, :force => true do |t|
    t.string :name
    t.integer :parent_id
    t.belongs_to :workspace
    t.timestamps null: true
  end

  create_table :posts, :force => true do |t|
    t.string :body
    t.integer :subject_id
    t.string :subject_type
    t.timestamps null: true
  end
end

class User < ActiveRecord::Base
  has_many :workspaces
end

class Task < ActiveRecord::Base
  belongs_to :workspace
  has_many :sub_tasks, :foreign_key => :parent_id, :class_name => "Task"
  has_many :posts

  def tags
    %w[some tags]
  end
end

class Workspace < ActiveRecord::Base
  belongs_to :user
  has_many :tasks
  has_many :posts

  scope :owned_by, -> id { where(:user_id => id) }
  scope :numeric_description, -> description { where(:description => ["1", "2", "3"]) }

  def lead_user
    user
  end
end

class Post < ActiveRecord::Base
  belongs_to :subject, :polymorphic => true
end

User.create!(:id => 1, :username => "bob")
User.create!(:id => 2, :username => "jane")

Workspace.create!(:id => 1, :user_id => 1, :title => "bob workspace 1", :description => "a")
Workspace.create!(:id => 2, :user_id => 1, :title => "bob workspace 2", :description => "1")
Workspace.create!(:id => 3, :user_id => 1, :title => "bob workspace 3", :description => "b")
Workspace.create!(:id => 4, :user_id => 1, :title => "bob workspace 4", :description => "2")
Workspace.create!(:id => 5, :user_id => 2, :title => "jane workspace 1", :description => "c")
Workspace.create!(:id => 6, :user_id => 2, :title => "jane workspace 2", :description => "3")

Task.create!(:id => 1, :workspace_id => 1, :name => "Buy milk")
Task.create!(:id => 2, :workspace_id => 1, :name => "Buy bananas")
Task.create!(:id => 3, :workspace_id => 1, :parent_id => 2, :name => "Green preferred")
Task.create!(:id => 4, :workspace_id => 1, :parent_id => 2, :name => "One bunch")

Post.create!(:id => 1, :subject => Workspace.first, :body => "first post!")
Post.create!(:id => 2, :subject => Task.first, :body => "this is important. get on it!")
Post.create!(:id => 3, :body => "Post without subject")