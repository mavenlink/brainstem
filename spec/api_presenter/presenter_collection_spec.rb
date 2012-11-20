require 'spec_helper'

describe ApiPresenter::PresenterCollection do
  class WorkspacePresenter < ApiPresenter::Base
    presents Workspace

    def present(model)
      {
        :id           => model.id,
        :title        => model.title,
        :description  => optional_field { model.description },
        :updated_at   => model.updated_at,
        :tasks        => association(:tasks)
      }
    end
  end

  #class TimeEntryPresenter < ApiPresenter::Base
  #  def present(model)
  #    {
  #      :id => model.id,
  #      :another_name_for_story => association { model.story }
  #    }
  #  end
  #end

  class TaskPresenter < ApiPresenter::Base
    presents Task

    def present(model)
      {
        :id           => model.id,
        :name         => model.name,
        :tags         => optional_field { model.tags },
        :sub_tasks    => association(:sub_tasks)
      }
    end
  end

  class UserPresenter < ApiPresenter::Base
    presents User

    def present(model)
      {
        :id           => model.id
      }
    end
  end

  before do
    UserPresenter.presents User
    TaskPresenter.presents Task
    WorkspacePresenter.presents Workspace
    @presenter_collection = ApiPresenter.presenter_collection
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

    describe "includes" do
      it "reads allowed includes from the presenter" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "drop table;tasks;time_entries" }) { Workspace.order('id desc') }
        result[:tasks].should be_present
        result[:time_entries].should_not be_present
      end

      #              |
      #             |
      # we're here \/

      it "allows the allowed includes list to have different json names and association names" do
        TimeEntryPresenter.allowed_includes(:another_name_for_story => {
          :association => :story, :json_name => "stories"})
        result = @presenter_collection.presenting("time_entries",
          :params => { :include => "another_name_for_story" }) { TimeEntry.where("true") }
        result[:stories].should be_present
        result[:time_entries].should be_present
      end

      it "defaults to not include any allowed includes" do
        WorkspacePresenter.allowed_includes :stories => "stories"
        result = @presenter_collection.presenting("workspaces", :max_per_page => 2) { Workspace.where(:id => workspaces(:jane_car_wash)) }
        result[:workspaces].first[:id].should == workspaces(:jane_car_wash).id
        result[:stories].should be_nil
      end

      it "loads has_many associations and returns them when requested" do
        WorkspacePresenter.allowed_includes :stories => "stories"
        result = @presenter_collection.presenting("workspaces", :params => { :include => "stories" }, :max_per_page => 2) { Workspace.where(:id => workspaces(:jane_car_wash)) }
        result[:stories].map { |s| s[:id] }.should =~ workspaces(:jane_car_wash).stories.map(&:id)
        result[:workspaces].first[:story_ids].should =~ workspaces(:jane_car_wash).stories.map(&:id)
      end

      it "returns optional fields when requested on the primary object and on associations" do
        WorkspacePresenter.allowed_includes :stories => "stories"
        result = @presenter_collection.presenting("workspaces",
                                                  :params => { :include => "stories:tags,title", :fields => "description" },
                                                  :max_per_page => 2) { Workspace.where(:id => workspaces(:jane_car_wash)) }
        result[:workspaces].first.should have_key(:description)
        result[:stories].first.should have_key(:tags)
        result[:stories].first.should have_key(:name)
      end

      it "does not return optional fields when they are not requested" do
        result = @presenter_collection.presenting("workspaces",
                                                  :params => { :include => "stories" },
                                                  :max_per_page => 2) { Workspace.where(:id => workspaces(:jane_car_wash)) }
        result[:workspaces].first.should_not have_key(:description)
        result[:stories].first.should_not have_key(:tags)
        result[:stories].first.should have_key(:name)
      end

      it "loads belongs_tos and returns them when requested" do
        TaskPresenter.allowed_includes :workspace => "workspaces"
        result = @presenter_collection.presenting("stories", :params => { :include => "workspace" }, :max_per_page => 2) { Story.where(:id => stories(:story_for_jane_car_wash).id) }
        result[:workspaces].first[:id].should == workspaces(:jane_car_wash).id
      end

      it "doesn't return nils when belong_tos are missing" do
        TimeEntryPresenter.allowed_includes :story => "stories"
        time_entry = line_items(:bob_logs_2hrs_billable)
        time_entry.story.should be_nil
        result = @presenter_collection.presenting("time_entries", :params => { :include => "story" }, :max_per_page => 2) { TimeEntry.where(:id => time_entry) }
        result[:time_entries].first[:id].should == time_entry.id
        result[:stories].length.should == 0
        result.keys.should =~ [:time_entries, :stories, :count]
      end

      it "returns sensible data when including something of the same type as the primary model" do
        TaskPresenter.allowed_includes :sub_stories => "stories"
        result = @presenter_collection.presenting("stories", :params => { :include => "sub_stories" }) { Story.where(:id => stories(:story_for_jane_car_wash).id) }
        result[:stories].map {|s| s[:id] }.should =~ ([stories(:story_for_jane_car_wash)] + stories(:story_for_jane_car_wash).sub_stories).map(&:id)
        result[:stories].find {|s| s[:id] == stories(:story_for_jane_car_wash).id }[:sub_story_ids].should == stories(:story_for_jane_car_wash).sub_stories.map(&:id) # The primary should have a sub_story_ids array.
        result[:stories].find {|s| s[:id] == stories(:story_for_jane_car_wash).sub_stories.first.id }[:sub_story_ids].should be_nil # Sub stories should not have a sub_story_ids array.
      end

      it "includes requested keys, even when empty" do
        WorkspacePresenter.allowed_includes :time_entries => "time_entries", :stories => "stories"
        result = @presenter_collection.presenting("workspaces", :params => { :only => "not an id", :include => "time_entries;stories" }) { Workspace.order("id desc") }
        result[:workspaces].length.should == 0
        result[:time_entries].length.should == 0
        result[:stories].length.should == 0
      end

      it "includes requested includes even when no records are found" do
        TimeEntryPresenter.allowed_includes :workspace => "workspaces", :story => "stories"
        TimeEntry.where(:id => 123456789).should be_empty
        result = @presenter_collection.presenting("time_entries", :params => { :include => "workspace;story" }) { TimeEntry.where(:id => 123456789) }
        result[:workspaces].length.should == 0
        result[:time_entries].length.should == 0
        result[:stories].length.should == 0
      end

      it "preloads associations when they are full model-level associations, but also works with model methods (without preloading)" do
        # Here, primary_maven is a method on Workspace, not a true association.
        @presenter_collection.presenting("workspaces", :params => { :include => "stories;primary_maven" }) { Workspace.where(:id => workspaces(:jane_car_wash).id) }

        WorkspacePresenter.allowed_includes :stories => "stories", :primary_maven => "users"
        mock(ActiveRecord::Associations::Preloader).new(anything, [:stories]) { mock!.run }
        result = @presenter_collection.presenting("workspaces", :params => { :include => "stories;primary_maven" }) { Workspace.where(:id => workspaces(:jane_car_wash).id) }
        result[:stories].should be_present
        result[:users].first[:id].should == users(:bob).id
      end
    end

    describe "handling of only" do
      it "accepts params[:only] as a list of ids to limit to" do
        workspace1 = create_workspace
        workspace2 = create_workspace
        workspace3 = create_workspace
        result = @presenter_collection.presenting("workspaces", :params => { :only => [workspace1.id, workspace3.id].join(",") }) { Workspace.order("id desc") }
        result[:workspaces].map { |w| w[:id] }.should =~ [workspace1.id, workspace3.id]
      end

      it "does not paginate only requests" do
        workspace1 = create_workspace
        workspace2 = create_workspace
        workspace3 = create_workspace
        dont_allow(@presenter_collection).paginate
        result = @presenter_collection.presenting("workspaces", :params => { :only => [workspace1.id, workspace3.id].join(",") }) { Workspace.order("id desc") }
      end

      it "escapes ids" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "#{workspaces(:jane_alone).id}foo,;drop tables;,#{workspaces(:jane_car_wash).id}" }) { Workspace.order("id desc") }
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
      it "runs filters when requested" do
        WorkspacePresenter.filter(:has_participant) { |scope, user_id| scope.has_participant(user_id.to_i) }
        WorkspacePresenter.filter(:price) { |scope, price| scope.where(:price => price) }

        result = @presenter_collection.presenting("workspaces", :params => { :filters => "has_participant:#{users(:bob).id}" }) { Workspace.order("id desc") } # hit the API, filtering on has_participant:bob
        result[:workspaces].should be_present
        bob_workspaces_ids = users(:bob).workspaces.map(&:id)
        result[:workspaces].all? {|w| bob_workspaces_ids.include?(w[:id]) }.should be_true # all of the returned workspaces should contain bob

        result = @presenter_collection.presenting("workspaces") { Workspace.order("id desc") } # hit the API again, this time not filtering on has_participant:bob
        result[:workspaces].all? {|w| bob_workspaces_ids.include?(w[:id]) }.should be_false # the returned workspaces no longer all contain bob

        result = @presenter_collection.presenting("workspaces", :params => { :filters => "has_participant:#{users(:bob).id},price:123" }) { Workspace.order("id desc") } # try two filters
        result[:workspaces].first[:id].should == workspaces(:jane_car_wash).id
      end

      it "allows filters to have defaults, which causes the filters to always be run" do
        WorkspacePresenter.filter(:include_archived, :default => false) { |scope, t_or_f| t_or_f != "true" ? scope.active : scope }
        result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [workspaces(:bob_change_order_archived).id, workspaces(:jane_car_wash).id]) }
        result[:workspaces].map {|w| w[:id] }.should == [workspaces(:jane_car_wash).id]

        result = @presenter_collection.presenting("workspaces", :params => { :filters => "include_archived:true" }) {Workspace.where(:id => [workspaces(:bob_change_order_archived).id, workspaces(:jane_car_wash).id])  }
        result[:workspaces].map {|w| w[:id] }.should =~ [workspaces(:bob_change_order_archived).id, workspaces(:jane_car_wash).id]
      end
    end

    describe "sorting and ordering" do
      before do
        @ws1 = create_workspace(:title => "c", :updated_at => 10.minutes.ago).id
        @ws2 = create_workspace(:title => "b", :updated_at => 30.minutes.ago).id
        @ws3 = create_workspace(:title => "a", :updated_at => 20.minutes.ago).id
      end

      context "when there is no sort provided" do
        before do
          @user = users(:newbie)
          @user.account.update_attribute(:subscription_plan, 'guru')
        end

        it "returns an empty array when there are no objects" do
          result = @presenter_collection.presenting("time_entries") { TimeEntry.viewable_by_user(@user) }
          result.should == {:count => 0, :time_entries => []}
        end

        it "falls back to the object's sort order when nothing is provided" do
          workspace = create_workspace(:title => "newbee workspace", :creator => @user, :is_budgeted => true)
          te1 = create_time_entry(:workspace => workspace, :user => @user)
          te2 = create_time_entry(:workspace => workspace, :user => @user)
          result = @presenter_collection.presenting("time_entries") { TimeEntry.viewable_by_user(@user).where(:id => [te2, te1]) }
          result[:time_entries].map {|i| i[:id]}.should == [te1.id, te2.id]
        end
      end

      it "allows default ordering descending" do
        WorkspacePresenter.sort_order(:updated_at, "workspaces.updated_at")
        WorkspacePresenter.default_sort_order("updated_at:desc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [@ws1, @ws2, @ws3]) }
        result[:workspaces].map {|i| i[:id]}.should == [@ws1, @ws3, @ws2]
      end

      it "allows default ordering ascending" do
        WorkspacePresenter.sort_order(:updated_at, "workspaces.updated_at")
        WorkspacePresenter.default_sort_order("updated_at:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [@ws1, @ws2, @ws3]) }
        result[:workspaces].map {|i| i[:id]}.should == [@ws2, @ws3, @ws1]
      end

      it "applies orders that match the default order" do
        WorkspacePresenter.sort_order(:updated_at, "workspaces.updated_at")
        WorkspacePresenter.default_sort_order("updated_at:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "updated_at:desc" }) { Workspace.where(:id => [@ws1, @ws2, @ws3]) }
        result[:workspaces].map {|i| i[:id]}.should == [@ws1, @ws3, @ws2]
      end

      it "applies orders that conflict with the default order" do
        WorkspacePresenter.sort_order(:updated_at, "workspaces.updated_at")
        WorkspacePresenter.default_sort_order("updated_at:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "updated_at:asc" }) { Workspace.where(:id => [@ws1, @ws2, @ws3]) }
        result[:workspaces].map {|i| i[:id]}.should == [@ws2, @ws3, @ws1]
      end

      it "cleans the direction param" do
        result = @presenter_collection.presenting("workspaces", :params => { :order => "updated_at:drop table" }) { Workspace.where(:id => [@ws1, @ws2, @ws3]) }
      end

      it "can take a proc" do
        WorkspacePresenter.sort_order(:title, "workspaces.title")
        WorkspacePresenter.default_sort_order("title:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [@ws1, @ws2, @ws3]) }
        result[:workspaces].map {|i| i[:id]}.should == [@ws3, @ws2, @ws1]
      end
    end
  end

  describe "internal helpers" do
    describe "#filter_includes" do
      it "allows only the allowed_includes and normalizes strings and symbols" do
        @presenter_collection.filter_includes("stories;drop tables;foo;time_entries", { 'stories' => :stories, :time_entries => "time_entries", :posts => "posts"}).should == {
            :stories => { :json_name => :stories, :association => :stories, :fields => [] },
            :time_entries => { :json_name => :time_entries, :association => :time_entries, :fields => [] }
        }
        @presenter_collection.filter_includes("stories:name,id;time_entries:title", { 'stories' => 'stories', :time_entries => :time_entries, :posts => :posts }).should == {
            :stories => { :json_name => :stories, :association => :stories, :fields => [:name, :id] },
            :time_entries => { :json_name => :time_entries, :association => :time_entries, :fields => [:title] }
        }
      end

      it "does not validate fields" do # these will need to be whitelisted in the presenters
        @presenter_collection.filter_includes("stories:drop table", { 'stories' => :stories, :time_entries => :time_entries, :posts => :posts }).should == {
            :stories => { :fields => [:"drop table"], :association => :stories, :json_name => :stories }
        }
      end

      it "allows you to supply the internal rails name of the association" do
        @presenter_collection.filter_includes("stories:title,id;time_entries:title",
                                              { 'stories' => { :association => 'internal_name',
                                                               :json_name => "stories" },
                                                :time_entries => :time_entries,
                                                :posts => :posts }).should == {
            :stories => { :json_name => :stories, :association => :internal_name, :fields => [:title, :id] },
            :time_entries => { :json_name => :time_entries, :association => :time_entries, :fields => [:title] }
        }
      end

      it "defaults to no includes" do
        @presenter_collection.filter_includes(nil, { :stories => :stories, :time_entries => :time_entries }).should == {}
        @presenter_collection.filter_includes("", { :stories => :stories, :time_entries => :time_entries }).should == {}
      end
    end
  end

  describe "collection methods" do
    describe "for method" do
      module V1
        class ArrayPresenter < ApiPresenter::Base
        end
      end

      before do
        V1::ArrayPresenter.presents Array
      end

      it "returns the presenter for a given class" do
        ApiPresenter.presenter_collection("v1").for(Array).should be_a(V1::ArrayPresenter)
      end

      it "returns nil when given nil" do
        ApiPresenter.presenter_collection("v1").for(nil).should be_nil
      end

      it "returns nil when a given class has no presenter" do
        ApiPresenter.presenter_collection("v1").for(String).should be_nil
      end
    end

    describe "for! method" do
      it "raises if there is no presenter for the given class" do
        lambda{ ApiPresenter.presenter_collection("v1").for!(String) }.should raise_error(ArgumentError)
      end
    end
  end
end