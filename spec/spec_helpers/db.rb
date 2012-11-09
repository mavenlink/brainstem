ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users do |t|
    t.string :username
    t.timestamps
  end

  create_table :workspaces do |t|
    t.string :title
    t.string :description
    t.belongs_to :user
    t.timestamps
  end

  create_table :tasks do |t|
    t.string :name
    t.belongs_to :workspace
    t.timestamps
  end
end

class User < ActiveRecord::Base
  has_many :workspaces
end

class Task < ActiveRecord::Base
  belongs_to :workspace
end

class Workspace < ActiveRecord::Base
  belongs_to :user
  has_many :tasks

  def lead_user
    user
  end
end

User.create!(:id => 1, :username => "bob")
User.create!(:id => 2, :username => "jane")
Workspace.create!(:id => 1, :user_id => 1, :title => "bob workspace 1", :description => "something")
Workspace.create!(:id => 2, :user_id => 1, :title => "bob workspace 2", :description => "something")
Workspace.create!(:id => 3, :user_id => 1, :title => "bob workspace 3", :description => "something")
Workspace.create!(:id => 4, :user_id => 1, :title => "bob workspace 4", :description => "something")
Workspace.create!(:id => 5, :user_id => 2, :title => "jane workspace 1", :description => "something")
Workspace.create!(:id => 6, :user_id => 2, :title => "jane workspace 2", :description => "something")

Task.create!(:id => 1, :workspace_id => 1, :name => "Buy milk")
Task.create!(:id => 2, :workspace_id => 1, :name => "Buy bananas")