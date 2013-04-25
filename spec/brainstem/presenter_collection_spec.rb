require 'spec_helper'
require 'spec_helpers/presenters'

describe Brainstem::PresenterCollection do
  before do
    UserPresenter.presents User
    TaskPresenter.presents Task
    WorkspacePresenter.presents Workspace
    PostPresenter.presents Post
    @presenter_collection = Brainstem.presenter_collection
  end

  describe "#presenting" do
    describe "#pagination" do
      before do
        @presenter_collection.default_per_page = 2
        @presenter_collection.default_max_per_page = 3
      end

      it "has a global per_page default" do
        @presenter_collection.presenting("workspaces") { Workspace.order('id desc') }[:workspaces].length.should == 2
      end

      it "will not accept a per_page less than 1" do
        @presenter_collection.presenting("workspaces", :params => { :per_page => 0 }) { Workspace.order('id desc') }[:workspaces].length.should == 2
      end

      it "will accept strings" do
        struct = @presenter_collection.presenting("workspaces", :params => { :per_page => "1", :page => "2" }) { Workspace.order('id desc') }
        struct[:results].first[:id].should == Workspace.order('id desc')[1].id.to_s
      end

      it "has a global max_per_page default" do
        @presenter_collection.presenting("workspaces", :params => { :per_page => 5 }) { Workspace.order('id desc') }[:workspaces].length.should == 3
      end

      it "takes a configurable default page size and max page size" do
        @presenter_collection.presenting("workspaces", :params => { :per_page => 5 }, :max_per_page => 4) { Workspace.order('id desc') }[:workspaces].length.should == 4
      end

      describe "limits and offsets" do
        it "honors the user's requested page size and page and returns counts" do
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 2 }) { Workspace.order('id desc') }[:results]
          result.length.should == 1
          result.first[:id].should == Workspace.order('id desc')[1].id.to_s

          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 2, :page => 2 }) { Workspace.order('id desc') }[:results]
          result.length.should == 2
          result.map { |m| m[:id] }.should == Workspace.order('id desc')[2..3].map(&:id).map(&:to_s)
        end

        it "defaults to 1 if the page number is less than 1" do
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 0 }) { Workspace.order('id desc') }[:results]
          result.length.should == 1
          result.first[:id].should == Workspace.order('id desc')[0].id.to_s
        end
      end

      describe "counts" do
        before do
          @presenter_collection.default_per_page = 500
          @presenter_collection.default_max_per_page = 500
        end

        it "returns the unique count by model id" do
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 2, :page => 1 }) { Workspace.order('id desc') }
          result[:count].should == Workspace.count
        end
      end
    end

    describe "uses presenters" do
      it "finds presenter by table name string" do
        result = @presenter_collection.presenting("workspaces") { Workspace.order('id desc') }
        result[:workspaces].length.should eq(Workspace.count)
      end

      it "finds presenter by model name string" do
        result = @presenter_collection.presenting("Workspace") { order('id desc') }
        result[:workspaces].length.should eq(Workspace.count)
      end

      it "finds presenter by model" do
        result = @presenter_collection.presenting(Workspace) { order('id desc') }
        result[:workspaces].length.should eq(Workspace.count)
      end

      it "infers the table name from the model" do
        result = @presenter_collection.presenting("not_workspaces", :model => "Workspace", :params => { :per_page => 2, :page => 1 }) { Workspace.order('id desc') }
        result[:not_workspaces].should_not be_empty
        result[:count].should == Workspace.count
      end
    end

    describe "the 'results' top level key" do
      it "comes back with an explicit list of the matching results" do
        structure = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }, :max_per_page => 2) { Workspace.where(:id => 1) }
        structure.keys.should =~ [:workspaces, :tasks, :count, :results]
        structure[:results].should == Workspace.where(:id => 1).limit(2).map {|w| { :key => "workspaces", :id => w.id.to_s } }
        structure[:workspaces].keys.should == %w[1]
      end
    end

    describe "includes" do
      it "reads allowed includes from the presenter" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "drop table,tasks,users" }) { Workspace.order('id desc') }
        result.keys.should =~ [:count, :workspaces, :tasks, :results]

        result = @presenter_collection.presenting("workspaces", :params => { :include => "foo,tasks,lead_user" }) { Workspace.order('id desc') }
        result.keys.should =~ [:count, :workspaces, :tasks, :users, :results]
      end

      it "allows the allowed includes list to have different json names and association names" do
        result = @presenter_collection.presenting("tasks",
          :params => { :include => "other_tasks" }) { Task.order('id desc') }
        result[:tasks].should be_present
        result[:other_tasks].should be_present
      end

      it "defaults to not include any allowed includes" do
        tasked_workspace = Task.first
        result = @presenter_collection.presenting("workspaces", :max_per_page => 2) { Workspace.where(:id => tasked_workspace.workspace_id) }
        result[:workspaces].keys.should == [ tasked_workspace.workspace_id.to_s ]
        result[:tasks].should be_nil
      end

      it "loads has_many associations and returns them when requested" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }, :max_per_page => 2) { Workspace.where(:id => 1) }
        result[:tasks].keys.should =~ Workspace.first.tasks.map(&:id).map(&:to_s)
        result[:workspaces]["1"][:task_ids].should =~ Workspace.first.tasks.map(&:id).map(&:to_s)
      end

      it "returns appropriate fields" do
        result = @presenter_collection.presenting("workspaces",
                                                  :params => { :include => "tasks" },
                                                  :max_per_page => 2) { Workspace.where(:id => 1) }
        result[:workspaces].values.first.should have_key(:description)
        result[:tasks].values.first.should have_key(:name)
      end

      it "loads belongs_tos and returns them when requested" do
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => 1) }
        result[:workspaces].keys.should == %w[1]
      end

      it "doesn't return nils when belong_tos are missing" do
        t = Task.first
        t.update_attribute :workspace, nil
        t.reload.workspace.should be_nil
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => t.id) }
        result[:tasks].keys.should == [ t.id.to_s ]
        result[:workspaces].should eq({})
        result.keys.should =~ [:tasks, :workspaces, :count, :results]
      end

      it "returns sensible data when including something of the same type as the primary model" do
        result = @presenter_collection.presenting("tasks", :params => { :include => "sub_tasks" }) { Task.where(:id => 2) }
        sub_task_ids = Task.find(2).sub_tasks.map(&:id).map(&:to_s)
        result[:tasks].keys.should =~ sub_task_ids + ["2"]
        result[:tasks]["2"][:sub_task_ids].should == sub_task_ids               # The primary should have a sub_story_ids array.
        result[:tasks][sub_task_ids.first][:sub_task_ids].should_not be_present # Sub stories should not have a sub_story_ids array.
      end

      it "includes requested includes even when all records are filtered" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "not an id", :include => "not an include,tasks" }) { Workspace.order("id desc") }
        result[:workspaces].length.should == 0
        result[:tasks].length.should == 0
      end

      it "includes requested includes even when the scope has no records" do
        Workspace.where(:id => 123456789).should be_empty
        result = @presenter_collection.presenting("workspaces", :params => { :include => "not an include,tasks" }) { Workspace.where(:id => 123456789) }
        result[:workspaces].length.should == 0
        result[:tasks].length.should == 0
      end

      it "preloads associations when they are full model-level associations" do
        # Here, primary_maven is a method on Workspace, not a true association.
        mock(ActiveRecord::Associations::Preloader).new(anything, [:tasks]) { mock!.run }
        result = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }) { Workspace.order('id desc') }
        result[:tasks].length.should > 0
      end

      it "works with model methods that load records (but without preloading)" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "lead_user" }) { Workspace.order('id desc') }
        result[:workspaces][Workspace.first.id.to_s].should be_present
        result[:users][Workspace.first.lead_user.id.to_s].should be_present
      end

      describe "polymorphic associations" do
        it "works with polymorphic associations" do
          result = @presenter_collection.presenting("posts", :params => { :include => "subject" }) { Post.order('id desc') }
          result[:posts][Post.first.id.to_s].should be_present
          result[:workspaces][Workspace.first.id.to_s].should be_present
          result[:tasks][Task.first.id.to_s].should be_present
        end

        it "does not return an empty hash when none are found" do
          result = @presenter_collection.presenting("posts", :params => { :include => "subject" }) { Post.where(:id => nil) }
          result.should have_key(:posts)
          result.should_not have_key(:workspaces)
          result.should_not have_key(:tasks)
        end
      end
    end

    describe "handling of only" do
      it "accepts params[:only] as a list of ids to limit to" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => Workspace.limit(2).pluck(:id).join(",") }) { Workspace.order("id desc") }
        result[:workspaces].keys.should match_array(Workspace.limit(2).pluck(:id).map(&:to_s))
      end

      it "does not paginate only requests" do
        dont_allow(@presenter_collection).paginate
        @presenter_collection.presenting("workspaces", :params => { :only => Workspace.limit(2).pluck(:id).join(",") }) { Workspace.order("id desc") }
      end

      it "escapes ids" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "#{Workspace.first.id}foo,;drop tables;,#{Workspace.first.id}" }) { Workspace.order("id desc") }
        result[:workspaces].length.should == 1
      end

      it "only runs when it receives ids" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "" }) { Workspace.order("id desc") }
        result[:workspaces].length.should > 1

        result = @presenter_collection.presenting("workspaces", :params => { :only => "1" }) { Workspace.order("id desc") }
        result[:workspaces].length.should <= 1
      end
    end

    describe "filters" do
      before do
        WorkspacePresenter.filter(:owned_by) { |scope, user_id| scope.owned_by(user_id.to_i) }
        WorkspacePresenter.filter(:title) { |scope, title| scope.where(:title => title) }
      end

      let(:bob) { User.where(:username => "bob").first }
      let(:bob_workspaces_ids) { bob.workspaces.map(&:id) }

      it "limits records to those matching given filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.id.to_s }) { Workspace.order("id desc") } # hit the API, filtering on owned_by:bob
        result[:workspaces].should be_present
        result[:workspaces].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }.should be_true # all of the returned workspaces should contain bob
      end

      it "returns all records if filters are not given" do
        result = @presenter_collection.presenting("workspaces") { Workspace.order("id desc") } # hit the API again, this time not filtering on anything
        result[:workspaces].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }.should be_false # the returned workspaces no longer all contain bob
      end

      it "ignores unknown filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :wut => "is this?" }) { Workspace.order("id desc") }
        result[:workspaces].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }.should be_false
      end

      it "limits records to those matching all given filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.id.to_s, :title => "bob workspace 1" }) { Workspace.order("id desc") } # try two filters
        result[:results].first[:id].should == Workspace.where(:title => "bob workspace 1").first.id.to_s
      end

      it "converts boolean parameters from strings to booleans" do
        WorkspacePresenter.filter(:owned_by_bob) { |scope, boolean| boolean ? scope.where(:user_id => bob.id) : scope }
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by_bob => "false" }) { Workspace.scoped }
        result[:workspaces].values.find { |workspace| workspace[:title].include?("jane") }.should be
      end

      it "allows filters to be called with false as an argument" do
        WorkspacePresenter.filter(:nothing) { |scope, bool| bool ? scope.where(:id => nil) : scope }
        result = @presenter_collection.presenting("workspaces", :params => { :nothing => "true" }) { Workspace.scoped }
        result[:workspaces].length.should eq(0)
        result = @presenter_collection.presenting("workspaces", :params => { :nothing => "false" }) { Workspace.scoped }
        result[:workspaces].length.should_not eq(0)
      end

      it "passes colon separated params through as a string" do
        WorkspacePresenter.filter(:between) { |scope, a_and_b|
          a, b = a_and_b.split(':')
          a.should == "1"
          b.should == "10"
          scope
        }

        @presenter_collection.presenting("workspaces", :params => { :between => "1:10" }) { Workspace.scoped }
      end

      context "with defaults" do
        before do
          WorkspacePresenter.filter(:owner, :default => bob.id) { |scope, id| scope.owned_by(id) }
        end

        let(:jane) { User.where(:username => "jane").first }

        it "applies the filter when it is not requested" do
          result = @presenter_collection.presenting("workspaces") { Workspace.order('id desc') }
          result[:workspaces].keys.should match_array(bob.workspaces.map(&:id).map(&:to_s))
        end

        it "allows falsy defaults" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
          result[:workspaces]["2"].should_not be_present
          result = @presenter_collection.presenting("workspaces", :params => { :include_early_workspaces => "true" }) { Workspace.unscoped }
          result[:workspaces]["2"].should be_present
        end

        it "allows defaults to be skipped if :apply_default_filters is false" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => true) { Workspace.unscoped }
          result[:workspaces]["2"].should_not be_present
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => false) { Workspace.unscoped }
          result[:workspaces]["2"].should be_present
        end

        it "allows the default value to be overridden" do
          result = @presenter_collection.presenting("workspaces", :params => { :owner => jane.id.to_s }) { Workspace.order('id desc') }
          result[:workspaces].keys.should match_array(jane.workspaces.map(&:id).map(&:to_s))
        end
      end

      context "without blocks" do
        let(:bob) { User.where(:username => "bob").first }
        let(:jane) { User.where(:username => "jane").first }

        before do
          WorkspacePresenter.filter(:owned_by, :default => bob.id)
          WorkspacePresenter.presents("Workspace")
        end

        it "calls the named scope with default arguments" do
          result = @presenter_collection.presenting("workspaces") { Workspace.scoped }
          result[:workspaces].keys.should eq(bob.workspaces.pluck(:id).map(&:to_s))
        end

        it "calls the named scope with given arguments" do
          result = @presenter_collection.presenting("workspaces", :params => { :owned_by => jane.id.to_s }) { Workspace.scoped }
          result[:workspaces].keys.should eq(jane.workspaces.pluck(:id).map(&:to_s))
        end
      end
    end

    describe "search" do
      context "with search method defined" do
        before do
          WorkspacePresenter.search do |string|
            [3,5]
          end
        end

        context "and a search request is made" do
          it "calls the search method" do
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
            result[:workspaces].keys.should eq(%w[3 5])
          end
        end

        context "and there is no search request" do
          it "does not call the search method" do
            result = @presenter_collection.presenting("workspaces") { Workspace.order("id asc") }
            result[:workspaces].keys.should eq(Workspace.pluck(:id).map(&:to_s))
          end
        end
      end

      context "without search method defined" do
        context "and a search request is made" do
          it "returns as if there was no search" do
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
            result[:workspaces].keys.should eq(Workspace.pluck(:id).map(&:to_s))
          end
        end
      end
    end

    describe "sorting and ordering" do
      context "when there is no sort provided" do
        it "returns an empty array when there are no objects" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => nil) }
          result.should eq(:count => 0, :workspaces => {}, :results => [])
        end

        it "falls back to the object's sort order when nothing is provided" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [1, 3]) }
          result[:workspaces].keys.should == %w[1 3]
        end
      end

      it "allows default ordering descending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        result[:results].map {|i| result[:workspaces][i[:id]][:description] }.should eq(%w(c b a 3 2 1))
      end

      it "allows default ordering ascending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        result[:results].map {|i| result[:workspaces][i[:id]][:description] }.should eq(%w(1 2 3 a b c))
      end

      it "applies orders that match the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:desc"} ) { Workspace.where("id is not null") }
        result[:results].map {|i| result[:workspaces][i[:id]][:description] }.should eq(%w(c b a 3 2 1))
      end

      it "applies orders that conflict with the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:asc"} ) { Workspace.where("id is not null") }
        result[:results].map {|i| result[:workspaces][i[:id]][:description] }.should eq(%w(1 2 3 a b c))
      end

      it "cleans the direction param" do
        result = @presenter_collection.presenting("workspaces", :params => { :order => "updated_at:drop table" }) { Workspace.where("id is not null") }
        result.keys.should =~ [:count, :workspaces, :results]
      end

      it "can take a proc" do
        WorkspacePresenter.sort_order(:description){ Workspace.order("workspaces.description") }
        WorkspacePresenter.default_sort_order("description:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        result[:results].map {|i| result[:workspaces][i[:id]][:description] }.should eq(%w(1 2 3 a b c))
      end
    end

    describe "the :as param" do
      it "determines the chosen top-level key name" do
        result = @presenter_collection.presenting("workspaces", :as => :my_workspaces) { Workspace.where(:id => 1) }
        result.keys.should eq([:count, :my_workspaces, :results])
      end
    end
  end

  describe "collection methods" do
    describe "for method" do
      module V1
        class ArrayPresenter < Brainstem::Presenter
        end
      end

      before do
        V1::ArrayPresenter.presents Array
      end

      it "returns the presenter for a given class" do
        Brainstem.presenter_collection("v1").for(Array).should be_a(V1::ArrayPresenter)
      end

      it "returns nil when given nil" do
        Brainstem.presenter_collection("v1").for(nil).should be_nil
      end

      it "returns nil when a given class has no presenter" do
        Brainstem.presenter_collection("v1").for(String).should be_nil
      end

      it "uses the default namespace when the passed namespace is nil" do
        Brainstem.presenter_collection.should eq(Brainstem.presenter_collection(nil))
      end
    end

    describe "for! method" do
      it "raises if there is no presenter for the given class" do
        lambda{ Brainstem.presenter_collection("v1").for!(String) }.should raise_error(ArgumentError)
      end
    end
  end
end
