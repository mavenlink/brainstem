ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users, :force => true do |t|
    t.string :username
    t.timestamps null: true
  end

  create_table :workspaces, :force => true do |t|
    t.string :type
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
    t.integer :user_id
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

  def secret_info
    "this is secret!"
  end

  def lead_user
    user
  end
end

class SubWorkspace < Workspace
end

class Post < ActiveRecord::Base
  belongs_to :user
  belongs_to :subject, :polymorphic => true
end