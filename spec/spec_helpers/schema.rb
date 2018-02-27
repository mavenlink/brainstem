if ENV['USE_MYSQL']
  ActiveRecord::Base.establish_connection(:adapter => 'mysql2', :database => 'test', :username => 'root', :password => '', :host => '127.0.0.1')
else
  ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
end

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

  create_table :attachments, :force => true do |t|
    t.string :type, null: false
    t.string :filename
    t.integer :subject_id
    t.string :subject_type
    t.timestamps null: true
  end

  create_table :cheeses, force: true do |t|
    t.integer :user_id
    t.string :flavor
  end
end

class User < ActiveRecord::Base
  has_many :workspaces

  def type
    self.class.name
  end
end

class Task < ActiveRecord::Base
  belongs_to :workspace
  belongs_to :parent, :class_name => "Task"
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

  def members
    [user]
  end

  def lead_user
    user
  end

  def missing_user
    nil
  end

  def type
    self.class.name
  end
end

class Group < Workspace
  def secret_info
    "groups have different secret info"
  end
end

class Post < ActiveRecord::Base
  belongs_to :user
  belongs_to :subject, polymorphic: true
  has_many :attachments, as: :subject, class_name: 'Attachments::PostAttachment'

  def things
    [Workspace.first, Post.first, Task.first]
  end
end

class Cheese < ActiveRecord::Base
  belongs_to :user

  scope :owned_by, -> id { where(user_id: id) }
end

module Attachments
  class Base < ActiveRecord::Base
    self.table_name = :attachments
    belongs_to :subject, polymorphic: true
  end

  class PostAttachment < Base
  end

  class TaskAttachment < Base
  end
end
