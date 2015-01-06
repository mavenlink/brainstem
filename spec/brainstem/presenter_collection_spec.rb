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

  let(:bob) { User.where(:username => "bob").first }
  let(:bob_workspaces_ids) { bob.workspaces.map(&:id) }
  let(:jane) { User.where(:username => "jane").first }

  describe "#presenting" do
    describe "#pagination" do
      before do
        @presenter_collection.default_per_page = 2
        @presenter_collection.default_max_per_page = 3
      end

      it "has a global per_page default" do
        expect(@presenter_collection.presenting("workspaces") { Workspace.order('id desc') }[:workspaces].length).to eq(2)
      end

      it "will not accept a per_page less than 1" do
        expect(@presenter_collection.presenting("workspaces", :params => { :per_page => 0 }) { Workspace.order('id desc') }[:workspaces].length).to eq(2)
        expect(@presenter_collection.presenting("workspaces", :per_page => 0) { Workspace.order('id desc') }[:workspaces].length).to eq(2)
      end

      it "will accept strings" do
        struct = @presenter_collection.presenting("workspaces", :params => { :per_page => "1", :page => "2" }) { Workspace.order('id desc') }
        expect(struct[:results].first[:id]).to eq(Workspace.order('id desc')[1].id.to_s)
      end

      it "has a global max_per_page default" do
        expect(@presenter_collection.presenting("workspaces", :params => { :per_page => 5 }) { Workspace.order('id desc') }[:workspaces].length).to eq(3)
      end

      it "takes a configurable default page size and max page size" do
        expect(@presenter_collection.presenting("workspaces", :params => { :per_page => 5 }, :max_per_page => 4) { Workspace.order('id desc') }[:workspaces].length).to eq(4)
      end

      describe "limits and offsets" do
        context "when only per_page and page are present" do
          it "honors the user's requested page size and page and returns counts" do
            result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 2 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(1)
            expect(result.first[:id]).to eq(Workspace.order('id desc')[1].id.to_s)

            result = @presenter_collection.presenting("workspaces", :params => { :per_page => 2, :page => 2 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(2)
            expect(result.map { |m| m[:id] }).to eq(Workspace.order('id desc')[2..3].map(&:id).map(&:to_s))
          end

          it "defaults to 1 if the page number is less than 1" do
            result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 0 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(1)
            expect(result.first[:id]).to eq(Workspace.order('id desc')[0].id.to_s)
          end
        end

        context "when only limit and offset are present" do
          it "honors the user's requested limit and offset and returns counts" do
            result = @presenter_collection.presenting("workspaces", :params => { :limit => 1, :offset => 2 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(1)
            expect(result.first[:id]).to eq(Workspace.order('id desc')[2].id.to_s)

            result = @presenter_collection.presenting("workspaces", :params => { :limit => 2, :offset => 2 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(2)
            expect(result.map { |m| m[:id] }).to eq(Workspace.order('id desc')[2..3].map(&:id).map(&:to_s))
          end

          it "defaults to offset 0 if the passed offset is less than 0 and limit to 1 if the passed limit is less than 1" do
            stub.proxy(@presenter_collection).calculate_offset(anything).times(1)
            stub.proxy(@presenter_collection).calculate_limit(anything).times(1)
            result = @presenter_collection.presenting("workspaces", :params => { :limit => -1, :offset => -1 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(1)
            expect(result.first[:id]).to eq(Workspace.order('id desc')[0].id.to_s)
          end
        end

        context "when both sets of params are present" do
          it "prefers limit and offset over per_page and page" do
            result = @presenter_collection.presenting("workspaces", :params => { :limit => 1, :offset => 0, :per_page => 2, :page => 2 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(1)
            expect(result.first[:id]).to eq(Workspace.order('id desc')[0].id.to_s)
          end

          it "uses per_page and page if limit and offset are not complete" do
            result = @presenter_collection.presenting("workspaces", :params => { :limit => 5, :per_page => 1, :page => 0 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(1)
            expect(result.first[:id]).to eq(Workspace.order('id desc')[0].id.to_s)

            result = @presenter_collection.presenting("workspaces", :params => { :offset => 5, :per_page => 1, :page => 0 }) { Workspace.order('id desc') }[:results]
            expect(result.length).to eq(1)
            expect(result.first[:id]).to eq(Workspace.order('id desc')[0].id.to_s)
          end
        end
      end

      describe "raise_on_empty option" do
        context "raise_on_empty is true" do
          context "results are empty" do
            it "should raise the provided error class when the empty_error_class option is provided" do
              class MyException < Exception; end

              expect {
                @presenter_collection.presenting("workspaces", :raise_on_empty => true, :empty_error_class => MyException) { Workspace.where(:id => nil) }
              }.to raise_error(MyException)
            end

            it "should raise ActiveRecord::RecordNotFound when the empty_error_class option is not provided" do
              expect {
                @presenter_collection.presenting("workspaces", :raise_on_empty => true) { Workspace.where(:id => nil) }
              }.to raise_error(ActiveRecord::RecordNotFound)
            end
          end

          context "results are not empty" do
            it "should not raise an exception" do
              expect(Workspace.count).to be > 0

              expect {
                @presenter_collection.presenting("workspaces", :raise_on_empty => true) { Workspace.order('id desc') }
              }.not_to raise_error
            end
          end
        end

        context "raise_on_empty is false" do
          it "should not raise an exception when the results are empty" do
            expect {
              @presenter_collection.presenting("workspaces") { Workspace.where(:id => nil) }
            }.not_to raise_error
          end
        end
      end

      describe "counts" do
        before do
          @presenter_collection.default_per_page = 500
          @presenter_collection.default_max_per_page = 500
        end

        it "returns the unique count by model id" do
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 2, :page => 1 }) { Workspace.order('id desc') }
          expect(result[:count]).to eq(Workspace.count)
        end
      end
    end

    describe "uses presenters" do
      it "finds presenter by table name string" do
        result = @presenter_collection.presenting("workspaces") { Workspace.order('id desc') }
        expect(result[:workspaces].length).to eq(Workspace.count)
      end

      it "finds presenter by model name string" do
        result = @presenter_collection.presenting("Workspace") { order('id desc') }
        expect(result[:workspaces].length).to eq(Workspace.count)
      end

      it "finds presenter by model" do
        result = @presenter_collection.presenting(Workspace) { order('id desc') }
        expect(result[:workspaces].length).to eq(Workspace.count)
      end

      it "infers the table name from the model" do
        result = @presenter_collection.presenting("not_workspaces", :model => "Workspace", :params => { :per_page => 2, :page => 1 }) { Workspace.order('id desc') }
        expect(result[:not_workspaces]).not_to be_empty
        expect(result[:count]).to eq(Workspace.count)
      end
    end

    describe "the 'results' top level key" do
      it "comes back with an explicit list of the matching results" do
        structure = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }, :max_per_page => 2) { Workspace.where(:id => 1) }
        expect(structure.keys).to match_array([:workspaces, :tasks, :count, :results])
        expect(structure[:results]).to eq(Workspace.where(:id => 1).limit(2).map {|w| { :key => "workspaces", :id => w.id.to_s } })
        expect(structure[:workspaces].keys).to eq(%w[1])
      end
    end

    describe "includes" do
      it "reads allowed includes from the presenter" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "drop table,tasks,users" }) { Workspace.order('id desc') }
        expect(result.keys).to match_array([:count, :workspaces, :tasks, :results])

        result = @presenter_collection.presenting("workspaces", :params => { :include => "foo,tasks,lead_user" }) { Workspace.order('id desc') }
        expect(result.keys).to match_array([:count, :workspaces, :tasks, :users, :results])
      end

      it "allows the allowed includes list to have different json names and association names" do
        result = @presenter_collection.presenting("tasks",
          :params => { :include => "other_tasks" }) { Task.order('id desc') }
        expect(result[:tasks]).to be_present
        expect(result[:other_tasks]).to be_present
      end

      it "defaults to not include any allowed includes" do
        tasked_workspace = Task.first
        result = @presenter_collection.presenting("workspaces", :max_per_page => 2) { Workspace.where(:id => tasked_workspace.workspace_id) }
        expect(result[:workspaces].keys).to eq([ tasked_workspace.workspace_id.to_s ])
        expect(result[:tasks]).to be_nil
      end

      it "loads has_many associations and returns them when requested" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }, :max_per_page => 2) { Workspace.where(:id => 1) }
        expect(result[:tasks].keys).to match_array(Workspace.first.tasks.map(&:id).map(&:to_s))
        expect(result[:workspaces]["1"][:task_ids]).to match_array(Workspace.first.tasks.map(&:id).map(&:to_s))
      end

      it "returns appropriate fields" do
        result = @presenter_collection.presenting("workspaces",
                                                  :params => { :include => "tasks" },
                                                  :max_per_page => 2) { Workspace.where(:id => 1) }
        expect(result[:workspaces].values.first).to have_key(:description)
        expect(result[:tasks].values.first).to have_key(:name)
      end

      it "loads belongs_tos and returns them when requested" do
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => 1) }
        expect(result[:workspaces].keys).to eq(%w[1])
      end

      it "doesn't return nils when belong_tos are missing" do
        t = Task.first
        t.update_attribute :workspace, nil
        expect(t.reload.workspace).to be_nil
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => t.id) }
        expect(result[:tasks].keys).to eq([ t.id.to_s ])
        expect(result[:workspaces]).to eq({})
        expect(result.keys).to match_array([:tasks, :workspaces, :count, :results])
      end

      it "returns sensible data when including something of the same type as the primary model" do
        result = @presenter_collection.presenting("tasks", :params => { :include => "sub_tasks" }) { Task.where(:id => 2) }
        sub_task_ids = Task.find(2).sub_tasks.map(&:id).map(&:to_s)
        expect(result[:tasks].keys).to match_array(sub_task_ids + ["2"])
        expect(result[:tasks]["2"][:sub_task_ids]).to eq(sub_task_ids)               # The primary should have a sub_story_ids array.
        expect(result[:tasks][sub_task_ids.first][:sub_task_ids]).not_to be_present # Sub stories should not have a sub_story_ids array.
      end

      it "includes requested includes even when all records are filtered" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "not an id", :include => "not an include,tasks" }) { Workspace.order("id desc") }
        expect(result[:workspaces].length).to eq(0)
        expect(result[:tasks].length).to eq(0)
      end

      it "includes requested includes even when the scope has no records" do
        expect(Workspace.where(:id => 123456789)).to be_empty
        result = @presenter_collection.presenting("workspaces", :params => { :include => "not an include,tasks" }) { Workspace.where(:id => 123456789) }
        expect(result[:workspaces].length).to eq(0)
        expect(result[:tasks].length).to eq(0)
      end

      it "preloads associations when they are full model-level associations" do
        # Here, primary_maven is a method on Workspace, not a true association.
        mock(Brainstem::PresenterCollection).preload(anything, [:tasks])
        result = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }) { Workspace.order('id desc') }
        expect(result[:tasks].length).to be > 0
      end

      it "works with model methods that load records (but without preloading)" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "lead_user" }) { Workspace.order('id desc') }
        expect(result[:workspaces][Workspace.first.id.to_s]).to be_present
        expect(result[:users][Workspace.first.lead_user.id.to_s]).to be_present
      end

      it "can accept a lambda for the association and uses that when present" do
        result = @presenter_collection.presenting("users", :params => { :include => "odd_workspaces" }) { User.where(:id => 1) }
        expect(result[:odd_workspaces][Workspace.first.id.to_s]).to be_present
        expect(result[:users][Workspace.first.lead_user.id.to_s]).to be_present
      end

      describe "restricted associations" do
        it "does apply includes that are restricted to only queries in an only query" do
          t = Task.first
          result = @presenter_collection.presenting("tasks", :params => { :include => "restricted", :only => t.id.to_s }, :max_per_page => 2) { Task.where(:id => t.id) }
          expect(result[:tasks][t.id.to_s].keys).to include(:restricted_id)
          expect(result.keys).to include(:restricted_associations)
        end

        it "does not apply includes that are restricted to only queries in a non-only query" do
          t = Task.first
          result = @presenter_collection.presenting("tasks", :params => { :include => "restricted" }, :max_per_page => 2) { Task.where(:id => t.id) }

          expect(result[:tasks][t.id.to_s].keys).not_to include(:restricted_id)
          expect(result.keys).not_to include(:restricted_associations)
        end
      end

      describe "polymorphic associations" do
        it "works with polymorphic associations" do
          result = @presenter_collection.presenting("posts", :params => { :include => "subject" }) { Post.order('id desc') }
          expect(result[:posts][Post.first.id.to_s]).to be_present
          expect(result[:workspaces][Workspace.first.id.to_s]).to be_present
          expect(result[:tasks][Task.first.id.to_s]).to be_present
        end

        it "does not return an empty hash when none are found" do
          result = @presenter_collection.presenting("posts", :params => { :include => "subject" }) { Post.where(:id => nil) }
          expect(result).to have_key(:posts)
          expect(result).not_to have_key(:workspaces)
          expect(result).not_to have_key(:tasks)
        end
      end
    end

    describe "handling of only" do
      it "accepts params[:only] as a list of ids to limit to" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => Workspace.limit(2).pluck(:id).join(",") }) { Workspace.order("id desc") }
        expect(result[:workspaces].keys).to match_array(Workspace.limit(2).pluck(:id).map(&:to_s))
      end

      it "does not paginate only requests" do
        dont_allow(@presenter_collection).paginate
        @presenter_collection.presenting("workspaces", :params => { :only => Workspace.limit(2).pluck(:id).join(",") }) { Workspace.order("id desc") }
      end

      it "escapes ids" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "#{Workspace.first.id}foo,;drop tables;,#{Workspace.first.id}" }) { Workspace.order("id desc") }
        expect(result[:workspaces].length).to eq(1)
      end

      it "only runs when it receives ids" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "" }) { Workspace.order("id desc") }
        expect(result[:workspaces].length).to be > 1

        result = @presenter_collection.presenting("workspaces", :params => { :only => "1" }) { Workspace.order("id desc") }
        expect(result[:workspaces].length).to be <= 1
      end
    end

    describe "filters" do
      before do
        WorkspacePresenter.filter(:owned_by) { |scope, user_id| scope.owned_by(user_id.to_i) }
        WorkspacePresenter.filter(:title) { |scope, title| scope.where(:title => title) }
      end

      it "limits records to those matching given filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.id.to_s }) { Workspace.order("id desc") } # hit the API, filtering on owned_by:bob
        expect(result[:workspaces]).to be_present
        expect(result[:workspaces].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }).to be_truthy # all of the returned workspaces should contain bob
      end

      it "returns all records if filters are not given" do
        result = @presenter_collection.presenting("workspaces") { Workspace.order("id desc") } # hit the API again, this time not filtering on anything
        expect(result[:workspaces].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }).to be_falsey # the returned workspaces no longer all contain bob
      end

      it "ignores unknown filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :wut => "is this?" }) { Workspace.order("id desc") }
        expect(result[:workspaces].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }).to be_falsey
      end

      it "limits records to those matching all given filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.id.to_s, :title => "bob workspace 1" }) { Workspace.order("id desc") } # try two filters
        expect(result[:results].first[:id]).to eq(Workspace.where(:title => "bob workspace 1").first.id.to_s)
      end

      it "converts boolean parameters from strings to booleans" do
        WorkspacePresenter.filter(:owned_by_bob) { |scope, boolean| boolean ? scope.where(:user_id => bob.id) : scope.where(:user_id => jane.id) }
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by_bob => "false" }) { Workspace.where(nil) }
        expect(result[:workspaces].values.find { |workspace| workspace[:title].include?("jane") }).to be
        expect(result[:workspaces].values.find { |workspace| workspace[:title].include?("bob") }).not_to be
      end

      it "ensures arguments are strings if they are not arrays" do
        filter_was_run = false
        WorkspacePresenter.filter(:owned_by_bob) do |scope, string|
          filter_was_run = true
          expect(string).to be_a(String)
          scope
        end
        @presenter_collection.presenting("workspaces", :params => { :owned_by_bob => { :wut => "is this?" } }) { Workspace.where(nil) }
        expect(filter_was_run).to be_truthy
      end

      it "preserves array arguments" do
        filter_was_run = false
        WorkspacePresenter.filter(:owned_by_bob) do |scope, array|
          filter_was_run = true
          expect(array).to be_a(Array)
          scope
        end
        @presenter_collection.presenting("workspaces", :params => { :owned_by_bob => [1, 2] }) { Workspace.where(nil) }
        expect(filter_was_run).to be_truthy
      end

      it "allows filters to be called with false as an argument" do
        WorkspacePresenter.filter(:nothing) { |scope, bool| bool ? scope.where(:id => nil) : scope }
        result = @presenter_collection.presenting("workspaces", :params => { :nothing => "true" }) { Workspace.where(nil) }
        expect(result[:workspaces].length).to eq(0)
        result = @presenter_collection.presenting("workspaces", :params => { :nothing => "false" }) { Workspace.where(nil) }
        expect(result[:workspaces].length).not_to eq(0)
      end

      it "passes colon separated params through as a string" do
        WorkspacePresenter.filter(:between) { |scope, a_and_b|
          a, b = a_and_b.split(':')
          expect(a).to eq("1")
          expect(b).to eq("10")
          scope
        }

        @presenter_collection.presenting("workspaces", :params => { :between => "1:10" }) { Workspace.where(nil) }
      end

      context "with defaults" do
        before do
          WorkspacePresenter.filter(:owner, :default => bob.id) { |scope, id| scope.owned_by(id) }
        end

        let(:jane) { User.where(:username => "jane").first }

        it "applies the filter when it is not requested" do
          result = @presenter_collection.presenting("workspaces") { Workspace.order('id desc') }
          expect(result[:workspaces].keys).to match_array(bob.workspaces.map(&:id).map(&:to_s))
        end

        it "allows falsy defaults" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
          expect(result[:workspaces]["2"]).not_to be_present
          result = @presenter_collection.presenting("workspaces", :params => { :include_early_workspaces => "true" }) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).to be_present
        end

        it "allows defaults to be skipped if :apply_default_filters is false" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => true) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).not_to be_present
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => false) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).to be_present
        end

        it "allows defaults set to false to be skipped if params contain :apply_default_filters with a false value" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => "true" }) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).not_to be_present

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => true }) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).not_to be_present
        end

        it "allows defaults set to true to be skipped if params contain :apply_default_filters with a false value" do
          WorkspacePresenter.filter(:include_early_workspaces, :default => true) { |scope, bool| bool ? scope : scope.where("id > 3") }

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => "false" }) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).to be_present

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => false }) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).to be_present
        end

        it "allows the default value to be overridden" do
          result = @presenter_collection.presenting("workspaces", :params => { :owner => jane.id.to_s }) { Workspace.order('id desc') }
          expect(result[:workspaces].keys).to match_array(jane.workspaces.map(&:id).map(&:to_s))

          WorkspacePresenter.filter(:include_early_workspaces, :default => true) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces", :params => { :include_early_workspaces => "false" }) { Workspace.unscoped }
          expect(result[:workspaces]["2"]).not_to be_present
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
          result = @presenter_collection.presenting("workspaces") { Workspace.where(nil) }
          expect(result[:workspaces].keys).to eq(bob.workspaces.pluck(:id).map(&:to_s))
        end

        it "calls the named scope with given arguments" do
          result = @presenter_collection.presenting("workspaces", :params => { :owned_by => jane.id.to_s }) { Workspace.where(nil) }
          expect(result[:workspaces].keys).to eq(jane.workspaces.pluck(:id).map(&:to_s))
        end

        it "can use filters without lambdas in the presenter or model, but behaves strangely when false is given" do
          WorkspacePresenter.filter(:numeric_description)

          result = @presenter_collection.presenting("workspaces") { Workspace.where(nil) }
          expect(result[:workspaces].keys).to eq(%w[1 2 3 4])

          result = @presenter_collection.presenting("workspaces", :params => { :numeric_description => "true" }) { Workspace.where(nil) }
          expect(result[:workspaces].keys).to eq(%w[2 4])

          # This is probably not the behavior that the developer or user intends.  You should always use a one-argument lambda in your
          # model scope declaration!
          result = @presenter_collection.presenting("workspaces", :params => { :numeric_description => "false" }) { Workspace.where(nil) }
          expect(result[:workspaces].keys).to eq(%w[2 4])
        end
      end
    end

    describe "search" do
      context "with search method defined" do
        before do
          WorkspacePresenter.sort_order(:description, "workspaces.description")
          WorkspacePresenter.search do |string|
            [[5, 3], 2]
          end
        end

        context "and a search request is made" do
          it "calls the search method and maintains the resulting order" do
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
            expect(result[:workspaces].keys).to eq(%w[5 3])
            expect(result[:count]).to eq(2)
          end

          it "does not apply filters" do
            mock(@presenter_collection).run_filters(anything, anything).times(0)
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
          end

          it "does not apply ordering" do
            mock(@presenter_collection).handle_ordering(anything, anything).times(0)
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
          end

          it "does not try to handle only's" do
            mock(@presenter_collection).handle_only(anything, anything).times(0)
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
          end

          it "does not apply pagination" do
            mock(@presenter_collection).paginate(anything, anything).times(0)
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
          end

          it "keeps the records in the order returned by search" do
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }

          end

          it "throws a SearchUnavailableError if the search block returns false" do
            WorkspacePresenter.search do |string|
              false
            end

            expect {
              @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
            }.to raise_error(Brainstem::SearchUnavailableError)
          end

          describe "passing options to the search block" do
            it "passes the search method, the search string, includes, order, and paging options" do
              WorkspacePresenter.filter(:owned_by) { |scope| scope }
              WorkspacePresenter.search do |string, options|
                expect(string).to eq("blah")
                expect(options[:include]).to eq(["tasks", "lead_user"])
                expect(options[:owned_by]).to eq(false)
                expect(options[:order][:sort_order]).to eq("description")
                expect(options[:order][:direction]).to eq("desc")
                expect(options[:page]).to eq(2)
                expect(options[:per_page]).to eq(5)
                [[1], 1] # returned ids, count - not testing this in this set of specs
              end

              @presenter_collection.presenting("workspaces", :params => { :search => "blah", :include => "tasks,lead_user", :owned_by => "false", :order => "description:desc", :page => 2, :per_page => 5 }) { Workspace.order("id asc") }
            end

            describe "includes" do
              it "throws out requested inlcudes that the presenter does not have associations for" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:include]).to eq([])
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :include => "users"}) { Workspace.order("id asc") }
              end
            end

            describe "filters" do
              it "passes through the default filters if no filter is requested" do
                WorkspacePresenter.filter(:owned_by, :default => true) { |scope| scope }
                WorkspacePresenter.search do |string, options|
                  expect(options[:owned_by]).to eq(true)
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
              end

              it "throws out requested filters that the presenter does not have" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:highest_rated]).to be_nil
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :highest_rated => true}) { Workspace.order("id asc") }
              end

              it "does not pass through existing non-default filters that are not requested" do
                WorkspacePresenter.filter(:owned_by) { |scope| scope }
                WorkspacePresenter.search do |string, options|
                  expect(options.has_key?(:owned_by)).to eq(false)
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah"}) { Workspace.order("id asc") }
              end
            end

            describe "orders" do
              it "passes through the default sort order if no order is requested" do
                WorkspacePresenter.default_sort_order("description:desc")
                WorkspacePresenter.search do |string, options|
                  expect(options[:order][:sort_order]).to eq("description")
                  expect(options[:order][:direction]).to eq("desc")
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah"}) { Workspace.order("id asc") }
              end

              it "makes the sort order 'updated_at:desc' if the requested order doesn't match an existing sort order and there is no default" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:order][:sort_order]).to eq("updated_at")
                  expect(options[:order][:direction]).to eq("desc")
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :order => "created_at:asc"}) { Workspace.order("id asc") }
              end

              it "sanitizes sort orders" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:order][:sort_order]).to eq("description")
                  expect(options[:order][:direction]).to eq("asc")
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :order => "description:owned"}) { Workspace.order("id asc") }
              end
            end

            describe "pagination" do
              it "passes through limit and offset if they are requested" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:limit]).to eq(1)
                  expect(options[:offset]).to eq(2)
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :limit => 1, :offset => 2}) { Workspace.order("id asc") }
              end

              it "passes through only limit and offset if all pagination options are requested" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:limit]).to eq(1)
                  expect(options[:offset]).to eq(2)
                  expect(options[:per_page]).to eq(nil)
                  expect(options[:page]).to eq(nil)
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :limit => 1, :offset => 2, :per_page => 3, :page => 4}) { Workspace.order("id asc") }
              end

              it "passes through page and per_page when limit not present" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:limit]).to eq(nil)
                  expect(options[:offset]).to eq(nil)
                  expect(options[:per_page]).to eq(3)
                  expect(options[:page]).to eq(4)
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :offset => 2, :per_page => 3, :page => 4}) { Workspace.order("id asc") }
              end

              it "passes through page and per_page when offset not present" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:limit]).to eq(nil)
                  expect(options[:offset]).to eq(nil)
                  expect(options[:per_page]).to eq(3)
                  expect(options[:page]).to eq(4)
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :limit => 1, :per_page => 3, :page => 4}) { Workspace.order("id asc") }
              end

              it "passes through page and per_page by default" do
                WorkspacePresenter.search do |string, options|
                  expect(options[:limit]).to eq(nil)
                  expect(options[:offset]).to eq(nil)
                  expect(options[:per_page]).to eq(20)
                  expect(options[:page]).to eq(1)
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah"}) { Workspace.order("id asc") }
              end
            end
          end
        end

        context "and there is no search request" do
          it "does not call the search method" do
            result = @presenter_collection.presenting("workspaces") { Workspace.order("id asc") }
            expect(result[:workspaces].keys).to eq(Workspace.pluck(:id).map(&:to_s))
          end
        end
      end

      context "without search method defined" do
        context "and a search request is made" do
          it "returns as if there was no search" do
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
            expect(result[:workspaces].keys).to eq(Workspace.pluck(:id).map(&:to_s))
          end
        end
      end
    end

    describe "sorting and ordering" do
      context "when there is no sort provided" do
        it "returns an empty array when there are no objects" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => nil) }
          expect(result).to eq(:count => 0, :workspaces => {}, :results => [])
        end

        it "falls back to the object's sort order when nothing is provided" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [1, 3]) }
          expect(result[:workspaces].keys).to eq(%w[1 3])
        end
      end

      it "allows default ordering descending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:description] }).to eq(%w(c b a 3 2 1))
      end

      it "allows default ordering ascending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:description] }).to eq(%w(1 2 3 a b c))
      end

      it "applies orders that match the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:desc"} ) { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:description] }).to eq(%w(c b a 3 2 1))
      end

      it "applies orders that conflict with the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:asc"} ) { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:description] }).to eq(%w(1 2 3 a b c))
      end

      it "cleans the params" do
        last_direction = nil
        WorkspacePresenter.sort_order(:description, "workspaces.description") do |scope, direction|
          last_direction = direction
          scope
        end
        WorkspacePresenter.sort_order(:title, "workspaces.title")
        WorkspacePresenter.default_sort_order("description:desc")

        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:drop table" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('asc')
        expect(result.keys).to match_array([:count, :workspaces, :results])

        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:;;hacker;;" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('asc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:desc" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('desc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:asc" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('asc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "drop table:desc" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('desc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "title:desc" }) { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:title] }).to eq(["jane workspace 2", "jane workspace 1", "bob workspace 4", "bob workspace 3", "bob workspace 2", "bob workspace 1"])

        result = @presenter_collection.presenting("workspaces", :params => { :order => "title:hacker" }) { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:title] }).to eq(["bob workspace 1", "bob workspace 2", "bob workspace 3", "bob workspace 4", "jane workspace 1", "jane workspace 2"])

        result = @presenter_collection.presenting("workspaces", :params => { :order => "title:;;;drop table;;" }) { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:title] }).to eq(["bob workspace 1", "bob workspace 2", "bob workspace 3", "bob workspace 4", "jane workspace 1", "jane workspace 2"])
      end

      it "can take a proc" do
        WorkspacePresenter.sort_order(:id) { |scope, direction| scope.order("workspaces.id #{direction}") }
        WorkspacePresenter.default_sort_order("id:asc")

        # Default
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:description] }).to eq(%w(a 1 b 2 c 3))

        # Asc
        result = @presenter_collection.presenting("workspaces", :params => { :order => "id:asc" }) { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:description] }).to eq(%w(a 1 b 2 c 3))

        # Desc
        result = @presenter_collection.presenting("workspaces", :params => { :order => "id:desc" }) { Workspace.where("id is not null") }
        expect(result[:results].map {|i| result[:workspaces][i[:id]][:description] }).to eq(%w(3 c 2 b 1 a))
      end
    end

    describe "the :as param" do
      it "determines the chosen top-level key name" do
        result = @presenter_collection.presenting("workspaces", :as => :my_workspaces) { Workspace.where(:id => 1) }
        expect(result.keys).to eq([:count, :my_workspaces, :results])
      end
    end

    describe "the count top level key" do
      it "should return the total number of matched records" do
        WorkspacePresenter.filter(:owned_by) { |scope, user_id| scope.owned_by(user_id.to_i) }

        result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => 1) }
        expect(result[:count]).to eq(1)

        result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
        expect(result[:count]).to eq(Workspace.count)

        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.to_param }) { Workspace.unscoped }
        expect(result[:count]).to eq(Workspace.owned_by(bob.to_param).count)

        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.to_param }) { Workspace.group(:id) }
        expect(result[:count]).to eq(Workspace.owned_by(bob.to_param).count)
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
        expect(Brainstem.presenter_collection("v1").for(Array)).to be_a(V1::ArrayPresenter)
      end

      it "returns nil when given nil" do
        expect(Brainstem.presenter_collection("v1").for(nil)).to be_nil
      end

      it "returns nil when a given class has no presenter" do
        expect(Brainstem.presenter_collection("v1").for(String)).to be_nil
      end

      it "uses the default namespace when the passed namespace is nil" do
        expect(Brainstem.presenter_collection).to eq(Brainstem.presenter_collection(nil))
      end
    end

    describe "for! method" do
      it "raises if there is no presenter for the given class" do
        expect{ Brainstem.presenter_collection("v1").for!(String) }.to raise_error(ArgumentError)
      end
    end
  end
end
