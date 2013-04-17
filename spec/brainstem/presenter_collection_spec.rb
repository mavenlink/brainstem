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
        result = @presenter_collection.presenting("workspaces", :params => { :per_page => "1", :page => "2" }) { Workspace.order('id desc') }[:workspaces]
        result.first[:id].should == Workspace.order('id desc')[1].id
      end

      it "has a global max_per_page default" do
        @presenter_collection.presenting("workspaces", :params => { :per_page => 5 }) { Workspace.order('id desc') }[:workspaces].length.should == 3
      end

      it "takes a configurable default page size and max page size" do
        @presenter_collection.presenting("workspaces", :params => { :per_page => 5 }, :max_per_page => 4) { Workspace.order('id desc') }[:workspaces].length.should == 4
      end

      describe "limits and offsets" do
        it "honors the user's requested page size and page and returns counts" do
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 2 }) { Workspace.order('id desc') }[:workspaces]
          result.length.should == 1
          result.first[:id].should == Workspace.order('id desc')[1].id

          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 2, :page => 2 }) { Workspace.order('id desc') }[:workspaces]
          result.length.should == 2
          result.map { |m| m[:id] }.should == Workspace.order('id desc')[2..3].map(&:id)
        end

        it "returns a count of the total number of matched records" do
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 2 }) { Workspace.order('id desc') }
          result[:count].should == Workspace.count
        end

        it "defaults to 1 if the page number is less than 1" do
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 0 }) { Workspace.order('id desc') }[:workspaces]
          result.length.should == 1
          result.first[:id].should == Workspace.order('id desc')[0].id
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
        result[:workspaces].size.should eq(Workspace.count)
      end

      it "finds presenter by model name string" do
        result = @presenter_collection.presenting("Workspace") { order('id desc') }
        result[:workspaces].size.should eq(Workspace.count)
      end

      it "finds presenter by model" do
        result = @presenter_collection.presenting(Workspace) { order('id desc') }
        result[:workspaces].size.should eq(Workspace.count)
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
        structure[:results].should == Workspace.where(:id => 1).limit(2).map {|w| { :key => "workspaces", :id => w.id } }
      end
    end

    describe "includes" do
      it "reads allowed includes from the presenter" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "drop table;tasks;users" }) { Workspace.order('id desc') }
        result[:tasks].should be_present
        result[:users].should_not be_present
        result[:drop_table].should_not be_present
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
        result[:workspaces].first[:id].should == tasked_workspace.workspace_id
        result[:tasks].should be_nil
      end

      it "loads has_many associations and returns them when requested" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }, :max_per_page => 2) { Workspace.where(:id => 1) }
        result[:tasks].map { |s| s[:id] }.should =~ Workspace.first.tasks.map(&:id)
        result[:workspaces].first[:task_ids].should =~ Workspace.first.tasks.map(&:id)
      end

      it "returns optional fields when requested on the primary object and on associations" do
        result = @presenter_collection.presenting("workspaces",
                                                  :params => { :include => "tasks:tags,title", :fields => "description" },
                                                  :max_per_page => 2) { Workspace.where(:id => 1) }
        result[:workspaces].first.should have_key(:description)
        result[:tasks].first.should have_key(:tags)
        result[:tasks].first.should have_key(:name)
      end

      it "does not return optional fields when they are not requested" do
        result = @presenter_collection.presenting("workspaces",
                                                  :params => { :include => "tasks" },
                                                  :max_per_page => 2) { Workspace.where(:id => 1) }
        result[:tasks].first.should_not have_key(:tags)
        result[:tasks].first.should have_key(:name)
      end

      it "loads belongs_tos and returns them when requested" do
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => 1) }
        result[:workspaces].first[:id].should == 1
      end

      it "doesn't return nils when belong_tos are missing" do
        t = Task.first
        t.update_attribute :workspace, nil
        t.reload.workspace.should be_nil
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => t.id) }
        result[:tasks].first[:id].should == t.id
        result[:workspaces].should eq([])
        result.keys.should =~ [:tasks, :workspaces, :count, :results]
      end

      it "returns sensible data when including something of the same type as the primary model" do
        result = @presenter_collection.presenting("tasks", :params => { :include => "sub_tasks" }) { Task.where(:id => 2) }
        sub_task_ids = Task.find(2).sub_tasks.map(&:id)
        result[:tasks].map {|s| s[:id] }.should =~ sub_task_ids + [2]
        result[:tasks].find {|s| s[:id] == 2 }[:sub_task_ids].should == sub_task_ids # The primary should have a sub_story_ids array.
        result[:tasks].find {|s| s[:id] == sub_task_ids.first }[:sub_task_ids].should be_nil # Sub stories should not have a sub_story_ids array.
      end

      it "includes requested includes even when all records are filtered" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "not an id", :include => "not an include;tasks" }) { Workspace.order("id desc") }
        result[:workspaces].length.should == 0
        result[:tasks].length.should == 0
      end

      it "includes requested includes even when the scope has no records" do
        Workspace.where(:id => 123456789).should be_empty
        result = @presenter_collection.presenting("workspaces", :params => { :include => "not an include;tasks" }) { Workspace.where(:id => 123456789) }
        result[:workspaces].length.should == 0
        result[:tasks].length.should == 0
      end

      it "preloads associations when they are full model-level associations" do
        # Here, primary_maven is a method on Workspace, not a true association.
        mock(ActiveRecord::Associations::Preloader).new(anything, [:tasks]) { mock!.run }
        result = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }) { Workspace.order('id desc') }
        result[:tasks].should be_present
      end

      it "works with model methods that load records (but without preloading)" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "lead_user" }) { Workspace.order('id desc') }
        result[:workspaces].map{|w| w[:id] }.should include(Workspace.first.id)
        result[:users].map{|u| u[:id] }.should include(Workspace.first.lead_user.id)
      end

      describe "polymorphic associations" do
        it "works with polymorphic associations" do
          result = @presenter_collection.presenting("posts", :params => { :include => "subject" }) { Post.order('id desc') }
          result[:posts].map{|w| w[:id] }.should include(Post.first.id)
          result[:workspaces].map{|u| u[:id] }.should include(Workspace.first.id)
          result[:tasks].map{|u| u[:id] }.should include(Task.first.id)
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
        result[:workspaces].map { |w| w[:id] }.should match_array(Workspace.limit(2).pluck(:id))
      end

      it "does not paginate only requests" do
        dont_allow(@presenter_collection).paginate
        result = @presenter_collection.presenting("workspaces", :params => { :only => Workspace.limit(2).pluck(:id).join(",") }) { Workspace.order("id desc") }
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
        result = @presenter_collection.presenting("workspaces", :params => { :filters => "owned_by:#{bob.id}" }) { Workspace.order("id desc") } # hit the API, filtering on has_participant:bob
        result[:workspaces].should be_present
        result[:workspaces].all? {|w| bob_workspaces_ids.include?(w[:id]) }.should be_true # all of the returned workspaces should contain bob
      end

      it "returns all records if filters are not given" do
        result = @presenter_collection.presenting("workspaces") { Workspace.order("id desc") } # hit the API again, this time not filtering on has_participant:bob
        result[:workspaces].all? {|w| bob_workspaces_ids.include?(w[:id]) }.should be_false # the returned workspaces no longer all contain bob
      end

      it "limits records to those matching all given filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :filters => "owned_by:#{bob.id},title:bob workspace 1" }) { Workspace.order("id desc") } # try two filters
        result[:workspaces].first[:id].should == Workspace.where(:title => "bob workspace 1").first.id
      end

      it "converts boolean parameters from strings to booleans" do
        WorkspacePresenter.filter(:owned_by_bob) { |scope, boolean| boolean ? scope.where(:user_id => bob.id) : scope }
        result = @presenter_collection.presenting("workspaces", :params => { :filters => "owned_by_bob:false" }) { Workspace.scoped }
        result[:workspaces].find { |workspace| workspace[:title].include?("jane") }.should be
      end

      it "allows filters to be called with false as an argument" do
        WorkspacePresenter.filter(:nothing) { |scope, bool| bool ? scope.where(:id => nil) : scope }
        result = @presenter_collection.presenting("workspaces", :params => { :filters => "nothing:true" }) { Workspace.scoped }
        result[:workspaces].size.should eq(0)
        result = @presenter_collection.presenting("workspaces", :params => { :filters => "nothing:false" }) { Workspace.scoped }
        result[:workspaces].size.should_not eq(0)
      end

      it "passes additonal colon separated params through as a string" do
        WorkspacePresenter.filter(:between) { |scope, a_and_b|
          a, b = a_and_b.split(':')
          a.should == "1"
          b.should == "10"
          scope
        }

        @presenter_collection.presenting("workspaces", :params => { :filters => "between:1:10" }) { Workspace.scoped }
      end

      context "with defaults" do
        before do
          WorkspacePresenter.filter(:owner, :default => bob.id) { |scope, id| scope.owned_by(id) }
        end

        let(:jane) { User.where(:username => "jane").first }

        it "applies the filter when it is not requested" do
          result = @presenter_collection.presenting("workspaces") { Workspace.order('id desc') }
          result[:workspaces].map{|w| w[:id] }.should match_array(bob.workspaces.map(&:id))
        end

        it "allows falsy defaults" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
          result[:workspaces].map{|w| w[:id] }.should_not include(2)
          result = @presenter_collection.presenting("workspaces", :params => { :filters => "include_early_workspaces:true" }) { Workspace.unscoped }
          result[:workspaces].map{|w| w[:id] }.should include(2)
        end

        it "allows defaults to be skipped if :apply_default_filters is false" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => true) { Workspace.unscoped }
          result[:workspaces].map{|w| w[:id] }.should_not include(2)
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => false) { Workspace.unscoped }
          result[:workspaces].map{|w| w[:id] }.should include(2)
        end

        it "allows the default value to be overridden" do
          result = @presenter_collection.presenting("workspaces", :params => { :filters => "owner:#{jane.id}" }) { Workspace.order('id desc') }
          result[:workspaces].map{|w| w[:id] }.should match_array(jane.workspaces.map(&:id))
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
          result = @presenter_collection.presenting("workspaces", :params => { :filters => "owned_by" }) { Workspace.scoped }
          result[:workspaces].map{|w| w[:id] }.should eq(bob.workspaces.pluck(:id))
        end

        it "calls the named scope with given arguments" do
          result = @presenter_collection.presenting("workspaces", :params => { :filters => "owned_by:#{jane.id}" }) { Workspace.scoped }
          result[:workspaces].map{|w| w[:id] }.should eq(jane.workspaces.pluck(:id))
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
            result[:workspaces].map{|w| w[:id] }.should eq([3,5])
          end
        end

        context "and there is no search request" do
          it "does not call the search method" do
            result = @presenter_collection.presenting("workspaces") { Workspace.order("id asc") }
            result[:workspaces].map{|w| w[:id] }.should eq(Workspace.pluck(:id))
          end
        end
      end

      context "without search method defined" do
        context "and a search request is made" do
          it "returns as if there was no search" do
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
            result[:workspaces].map{|w| w[:id] }.should eq(Workspace.pluck(:id))
          end
        end
      end
    end

    describe "sorting and ordering" do
      context "when there is no sort provided" do
        it "returns an empty array when there are no objects" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => nil) }
          result.should eq(:count => 0, :workspaces => [], :results => [])
        end

        it "falls back to the object's sort order when nothing is provided" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [1, 3]) }
          result[:workspaces].map {|i| i[:id]}.should == [1, 3]
        end
      end

      it "allows default ordering descending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        result[:workspaces].map {|i| i[:description]}.should eq(%w(c b a 3 2 1))
      end

      it "allows default ordering ascending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        result[:workspaces].map {|i| i[:description]}.should eq(%w(1 2 3 a b c))
      end

      it "applies orders that match the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:desc"} ) { Workspace.where("id is not null") }
        result[:workspaces].map {|i| i[:description]}.should eq(%w(c b a 3 2 1))
      end

      it "applies orders that conflict with the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:asc"} ) { Workspace.where("id is not null") }
        result[:workspaces].map {|i| i[:description]}.should eq(%w(1 2 3 a b c))
      end

      it "cleans the direction param" do
        result = @presenter_collection.presenting("workspaces", :params => { :order => "updated_at:drop table" }) { Workspace.where("id is not null") }
      end

      it "can take a proc" do
        WorkspacePresenter.sort_order(:description){ Workspace.order("workspaces.description") }
        WorkspacePresenter.default_sort_order("description:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        result[:workspaces].map {|i| i[:description]}.should eq(%w(1 2 3 a b c))
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
