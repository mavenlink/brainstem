User.create!(:id => 1, :username => "bob")
User.create!(:id => 2, :username => "jane")

Workspace.create!(:id => 1, :user_id => 1, :title => "bob workspace 1", :description => "a")
Workspace.create!(:id => 2, :user_id => 1, :title => "bob workspace 2", :description => "1")
Workspace.create!(:id => 3, :user_id => 1, :title => "bob workspace 3", :description => "b")
Workspace.create!(:id => 4, :user_id => 1, :title => "bob workspace 4", :description => "2")
Workspace.create!(:id => 5, :user_id => 2, :title => "jane workspace 1", :description => "c")
Workspace.create!(:id => 6, :user_id => 2, :title => "jane workspace 2", :description => "3")

Cheese.create!(id: 1, user_id: 1, flavor: 'colby jack' )
Cheese.create!(id: 2, user_id: 1, flavor: 'swiss' )
Cheese.create!(id: 3, user_id: 1, flavor: 'cheese curds' )
Cheese.create!(id: 4, user_id: 1, flavor: 'bleu' )
Cheese.create!(id: 5, user_id: 1, flavor: 'cheddar' )
Cheese.create!(id: 6, user_id: 2, flavor: 'gorgonzola' )
Cheese.create!(id: 7, user_id: 1, flavor: 'search text' )
Cheese.create!(id: 8, user_id: 1, flavor: 'search text' )
Cheese.create!(id: 9, user_id: 2, flavor: 'provologne')
Cheese.create!(id: 10, user_id: 1, flavor: 'old amsterdam' )
Cheese.create!(id: 11, user_id: 1, flavor: 'brie' )
Cheese.create!(id: 12, user_id: 1, flavor: 'wensleydale' )
# Group.create!(:id => 7, :user_id => 2, :title => "a group", :description => "this is a group")

Task.create!(:id => 1, :workspace_id => 1, :name => "Buy milk")
Task.create!(:id => 2, :workspace_id => 1, :name => "Buy bananas")
Task.create!(:id => 3, :workspace_id => 1, :parent_id => 2, :name => "Green preferred")
Task.create!(:id => 4, :workspace_id => 1, :parent_id => 2, :name => "One bunch")
Task.create!(:id => 5, :workspace_id => 6, :name => "In another Workspace")

Post.create!(:id => 1, :user_id => 1, :subject => Workspace.first, :body => "first post!")
Post.create!(:id => 2, :user_id => 1, :subject => Task.first, :body => "this is important. get on it!")
Post.create!(:id => 3, :user_id => 2, :body => "Post without subject")

User.all.each do |user|
  Workspace.all.each do |workspace|
    LineItem.create!(user: user, workspace: workspace, amount: 123)
  end
end

Attachments::PostAttachment.create!(id: 1, subject: Post.first, filename: 'I am an attachment on a post')
Attachments::TaskAttachment.create!(id: 2, subject: Task.first, filename: 'I am an attachment on a task')

# TODO:
# user can group all of an STI structure into the brainstem_keys, of their choice
# user can put STI classes into seperate brainstem_keys
# inheriting presenters and showing that they work
# Spec presents attachments, including their subjects, shows that right presenters are used.
# Show that the base class is always used as the brainstem_key for attachments as polymorphic association targets

# Use Group / Workspace as the polymorphic target of an association where we do not
# want the baseclass to be used as the brainstem_key (like line_items0)
