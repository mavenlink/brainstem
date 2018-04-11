require 'spec_helper'

describe Brainstem::PresenterCollection do
  before do
    @presenter_collection = Brainstem.presenter_collection
  end

  let(:bob) { User.where(:username => "bob").first }
  let(:bob_workspaces_ids) { bob.workspaces.map(&:id) }
  let(:jane) { User.where(:username => "jane").first }

  describe "#presenting" do
    describe "pagination" do
      before do
        @presenter_collection.default_per_page = 2
        @presenter_collection.default_max_per_page = 3
      end

      it "has a global per_page default" do
        expect(@presenter_collection.presenting("workspaces") { Workspace.unscoped }['workspaces'].length).to eq(2)
      end

      it "will not accept a per_page less than 1" do
        expect(@presenter_collection.presenting("workspaces", :params => { :per_page => 0 }) { Workspace.unscoped }['workspaces'].length).to eq(2)
        expect(@presenter_collection.presenting("workspaces", :per_page => 0) { Workspace.unscoped }['workspaces'].length).to eq(2)
      end

      it "will accept strings" do
        struct = @presenter_collection.presenting("workspaces", :params => { :per_page => "1", :page => "2" }) { Workspace.unscoped }
        expect(struct['results'].first['id']).to eq(Workspace.unscoped[1].id.to_s)
      end

      it "has a global max_per_page default" do
        expect(@presenter_collection.presenting("workspaces", :params => { :per_page => 5 }) { Workspace.unscoped }['workspaces'].length).to eq(3)
      end

      it "takes a configurable default page size and max page size" do
        expect(@presenter_collection.presenting("workspaces", :params => { :per_page => 5 }, :max_per_page => 4) { Workspace.unscoped }['workspaces'].length).to eq(4)
      end

      describe "limits and offsets" do
        context "when only per_page and page are present" do
          it "honors the user's requested page size and page and returns counts" do
            result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 2 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(1)
            expect(result.first['id']).to eq(Workspace.unscoped[1].id.to_s)

            result = @presenter_collection.presenting("workspaces", :params => { :per_page => 2, :page => 2 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(2)
            expect(result.map { |m| m['id'] }).to eq(Workspace.unscoped[2..3].map(&:id).map(&:to_s))
          end

          it "defaults to 1 if the page number is less than 1" do
            result = @presenter_collection.presenting("workspaces", :params => { :per_page => 1, :page => 0 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(1)
            expect(result.first['id']).to eq(Workspace.unscoped[0].id.to_s)
          end

          it "restricts the per_page to options[:max_per_page], if provided, otherwise default_max_per_page" do
            result = @presenter_collection.presenting("workspaces", :max_per_page => 5, :params => { :per_page => 10000, :page => 1 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(5)

            result = @presenter_collection.presenting("workspaces", :params => { :per_page => 10000, :page => 1 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(3)
          end
        end

        context "when only limit and offset are present" do
          it "honors the user's requested limit and offset and returns counts" do
            result = @presenter_collection.presenting("workspaces", :params => { :limit => 1, :offset => 2 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(1)
            expect(result.first['id']).to eq(Workspace.unscoped[2].id.to_s)

            result = @presenter_collection.presenting("workspaces", :params => { :limit => 2, :offset => 2 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(2)
            expect(result.map { |m| m['id'] }).to eq(Workspace.unscoped[2..3].map(&:id).map(&:to_s))
          end

          it "defaults to offset 0 if the passed offset is less than 0 and limit to 1 if the passed limit is less than 1" do
            result = @presenter_collection.presenting("workspaces", :params => { :limit => -1, :offset => -1 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(1)
            expect(result.first['id']).to eq(Workspace.unscoped[0].id.to_s)
          end

          it "restricts the limit to options[:max_per_page], if provided, otherwise default_max_per_page" do
            result = @presenter_collection.presenting("workspaces", :max_per_page => 5, :params => { :limit => 100, :offset => 0 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(5)

            result = @presenter_collection.presenting("workspaces", :params => { :limit => 100, :offset => 0 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(3)
          end
        end

        context "when both sets of params are present" do
          it "prefers limit and offset over per_page and page" do
            result = @presenter_collection.presenting("workspaces", :params => { :limit => 1, :offset => 0, :per_page => 2, :page => 2 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(1)
            expect(result.first['id']).to eq(Workspace.unscoped[0].id.to_s)
          end

          it "uses per_page and page if limit and offset are not complete" do
            result = @presenter_collection.presenting("workspaces", :params => { :limit => 5, :per_page => 1, :page => 0 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(1)
            expect(result.first['id']).to eq(Workspace.unscoped[0].id.to_s)

            result = @presenter_collection.presenting("workspaces", :params => { :offset => 5, :per_page => 1, :page => 0 }) { Workspace.unscoped }['results']
            expect(result.length).to eq(1)
            expect(result.first['id']).to eq(Workspace.unscoped[0].id.to_s)
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
                @presenter_collection.presenting("workspaces", :raise_on_empty => true) { Workspace.unscoped }
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
          result = @presenter_collection.presenting("workspaces", :params => { :per_page => 2, :page => 1 }) { Workspace.unscoped }
          expect(result['count']).to eq(Workspace.count)
        end
      end

      describe "meta keys" do
        let(:max_per_page) { nil }
        let(:meta_keys) { result["meta"] }
        let(:result) { @presenter_collection.presenting("workspaces", params: params, max_per_page: max_per_page) { Workspace.unscoped } }

        describe "count" do
          let(:params) { {} }

          it "includes the count" do
            expect(meta_keys["count"]).to eq(6)
          end
        end

        describe "page_number" do
          describe "when page is provided" do
            let(:params) { { page: 2 } }

            it "indicates the provided page" do
              expect(meta_keys["page_number"]).to eq(2)
            end
          end

          describe "when page is not profided" do
            let(:params) { {} }

            it "indicates the first page" do
              expect(meta_keys["page_number"]).to eq(1)
            end
          end
        end

        describe "page_count" do
          describe "when per_page is provided" do
            let(:params) { { per_page: 4 } }

            it "calculates the correct page count" do
              expect(meta_keys["page_count"]).to eq(2)
            end
          end

          describe "when per_page is not provided" do
            let(:params) { {} }

            it "calculates the correct page count based on the default page size" do
              expect(meta_keys["page_count"]).to eq(3)
            end
          end
        end

        describe "page_size" do
          let(:params) { {} }

          it "calculates the correct page size" do
            expect(meta_keys["page_count"]).to eq(3)
          end
        end
      end
    end

    describe 'strategies' do
      let(:params) { { search: "tomato" } }

      context 'the user does not specify a strategy with the presenter DSL' do
        it 'uses the legacy FilterOrSearch strategy' do
          mock.proxy(Brainstem::QueryStrategies::FilterOrSearch).new(anything).times(1)
          result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
          expect(result['workspaces'].length).to eq(Workspace.count)
        end
      end

      context 'the user specifies the filter_and_search strategy as a symbol' do
        before do
          WorkspacePresenter.query_strategy :filter_and_search
        end

        context 'the user is searching' do
          before do
            WorkspacePresenter.search do |string|
              [[5, 3], 2]
            end
          end

          context 'the scope size is below default_max_filter_and_search_page' do
            before do
              @presenter_collection.default_max_filter_and_search_page = 500
            end

            it 'uses the FilterAndSearch strategy' do
              mock.proxy(Brainstem::QueryStrategies::FilterAndSearch).new(anything).times(1)
              result = @presenter_collection.presenting("workspaces", params: params) { Workspace.unscoped }
              expect(result['workspaces'].length).to eq(2)
            end
          end

          context 'the scope size is above default_max_filter_and_search_page' do
            before do
              @presenter_collection.default_max_filter_and_search_page = 2
            end

            # TODO: this will become the third, faster strategy for large pagesizes
            it 'uses the FilterOrSearch strategy' do
              mock.proxy(Brainstem::QueryStrategies::FilterOrSearch).new(anything).times(1)
              result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
              expect(result['workspaces'].length).to eq(Workspace.count)
            end
          end
        end

        context 'the user is not searching' do
          it 'uses the legacy FilterOrSearch strategy' do
            mock.proxy(Brainstem::QueryStrategies::FilterOrSearch).new(anything).times(1)
            result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
            expect(result['workspaces'].length).to eq(Workspace.count)
          end
        end
      end

      context 'the user passes a lambda as the query_strategy' do
        before do
          WorkspacePresenter.query_strategy lambda { :filter_and_search }

          WorkspacePresenter.search do |string|
            [[5, 3], 2]
          end
        end

        it 'uses the strategy returned by that lambda' do
          mock.proxy(Brainstem::QueryStrategies::FilterAndSearch).new(anything).times(1)
          result = @presenter_collection.presenting("workspaces", params: params) { Workspace.unscoped }
          expect(result['workspaces'].length).to eq(2)
        end
      end
    end

    describe "uses presenters" do
      it "finds presenter by table name string" do
        result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
        expect(result['workspaces'].length).to eq(Workspace.count)
      end

      it "finds presenter by model name string" do
        result = @presenter_collection.presenting("Workspace") { Workspace.unscoped }
        expect(result['workspaces'].length).to eq(Workspace.count)
      end

      it "finds presenter by model" do
        result = @presenter_collection.presenting(Workspace) { Workspace.unscoped }
        expect(result['workspaces'].length).to eq(Workspace.count)
      end
    end

    describe "the 'results' top level key" do
      it "comes back with an explicit list of the matching results" do
        structure = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }, :max_per_page => 2) { Workspace.where(:id => 1) }
        expect(structure.keys).to match_array %w[workspaces tasks count results meta]
        expect(structure['results']).to eq(Workspace.where(:id => 1).limit(2).map {|w| { 'key' => 'workspaces', 'id' => w.id.to_s } })
        expect(structure['workspaces'].keys).to eq(%w[1])
      end
    end

    describe "includes" do
      it "reads allowed includes from the presenter" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "drop table,tasks,users" }) { Workspace.unscoped }
        expect(result.keys).to match_array %w[count meta workspaces tasks results]

        result = @presenter_collection.presenting("workspaces", :params => { :include => "foo,tasks,lead_user" }) { Workspace.unscoped }
        expect(result.keys).to match_array %w[count meta workspaces tasks users results]
      end

      it "defaults to not include any allowed includes" do
        tasked_workspace = Task.first
        result = @presenter_collection.presenting("workspaces", :max_per_page => 2) { Workspace.where(:id => tasked_workspace.workspace_id) }
        expect(result['workspaces'].keys).to eq([ tasked_workspace.workspace_id.to_s ])
        expect(result['tasks']).to be_nil
      end

      it "loads has_many associations and returns them when requested" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "tasks" }, :max_per_page => 2) { Workspace.where(:id => 1) }
        expect(result['tasks'].keys).to match_array(Workspace.first.tasks.map(&:id).map(&:to_s))
        expect(result['workspaces']['1']['task_ids']).to match_array(Workspace.first.tasks.map(&:id).map(&:to_s))
      end

      it "returns appropriate fields" do
        result = @presenter_collection.presenting("workspaces",
                                                  :params => { :include => "tasks" },
                                                  :max_per_page => 2) { Workspace.where(:id => 1) }
        expect(result['workspaces'].values.first).to have_key('description')
        expect(result['tasks'].values.first).to have_key('name')
      end

      it "loads belongs_tos and returns them when requested" do
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => 1) }
        expect(result['workspaces'].keys).to eq(%w[1])
      end

      it "doesn't return nils when belong_tos are missing" do
        t = Task.first
        t.update_attribute :workspace, nil
        expect(t.reload.workspace).to be_nil
        result = @presenter_collection.presenting("tasks", :params => { :include => "workspace" }, :max_per_page => 2) { Task.where(:id => t.id) }
        expect(result['tasks'].keys).to eq([ t.id.to_s ])
        expect(result['workspaces']).to eq({})
        expect(result.keys).to match_array %w[tasks workspaces count meta results]
      end

      context 'when including something of the same type as the primary model' do
        it "returns sensible data" do
          result = @presenter_collection.presenting("tasks", :params => { :include => "sub_tasks" }) { Task.where(:id => 2) }
          sub_task_ids = Task.find(2).sub_tasks.map(&:id).map(&:to_s)
          expect(result['tasks'].keys).to match_array(sub_task_ids + ["2"])
          expect(result['tasks']['2']['sub_task_ids']).to eq(sub_task_ids)               # The primary should have a sub_story_ids array.
          expect(result['tasks'][sub_task_ids.first]).not_to have_key('sub_task_ids')    # Sub stories should not have a sub_story_ids array.
        end

        it 'uses the loaded data for the primary request when a model is found both in the primary set and in an inclusion' do
          result = @presenter_collection.presenting("tasks", :params => { :include => "sub_tasks" }) { Task.all }
          sub_task_ids = Task.find(2).sub_tasks.map(&:id).map(&:to_s)
          expect(result['tasks']['2']['sub_task_ids']).to eq(sub_task_ids)               # Sub stories were all loaded in the primary request this time,
          expect(result['tasks'][sub_task_ids.first]).to have_key('sub_task_ids')        # and should have associations loaded.
          expect(result['tasks'][sub_task_ids.first]['sub_task_ids']).to eq []
        end
      end

      it "includes requested includes even when all records are filtered" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "not an id", :include => "not an include,tasks" }) { Workspace.unscoped }
        expect(result['workspaces'].length).to eq(0)
        expect(result['tasks'].length).to eq(0)
      end

      it "includes requested includes even when the scope has no records" do
        expect(Workspace.where(:id => 123456789)).to be_empty
        result = @presenter_collection.presenting("workspaces", :params => { :include => "not an include,tasks" }) { Workspace.where(:id => 123456789) }
        expect(result['workspaces'].length).to eq(0)
        expect(result['tasks'].length).to eq(0)
      end

      it "works with model methods that load records" do
        result = @presenter_collection.presenting("workspaces", :params => { :include => "lead_user" }) { Workspace.unscoped }
        expect(result['workspaces'][Workspace.first.id.to_s]).to be_present
        expect(result['workspaces'][Workspace.first.id.to_s]['lead_user_id']).to eq Workspace.first.lead_user.id.to_s
        expect(result['users'][Workspace.first.lead_user.id.to_s]).to be_present
      end

      it "can accept a lambda for the association and uses that when present" do
        result = @presenter_collection.presenting("users", :params => { :include => "odd_workspaces" }) { User.where(:id => 1) }
        expect(result['users'][User.first.id.to_s]).to be_present
        odd_workspace_ids = User.first.workspaces.select { |w| w.id % 2 == 1 }.map(&:id).map(&:to_s)
        expect(result['users'][User.first.id.to_s]['odd_workspace_ids']).to eq odd_workspace_ids
        expect(result['workspaces'].keys).to eq odd_workspace_ids
      end

      describe "restricted associations" do
        it "does apply includes that are restricted to only queries in an only query" do
          t = Task.first
          result = @presenter_collection.presenting("tasks", :params => { :include => "restricted", :only => t.id.to_s }, :max_per_page => 2) { Task.where(:id => t.id) }
          expect(result['tasks'][t.id.to_s].keys).to include('restricted_id')
          expect(result['tasks'][Task.last.id.to_s]).to be_present
        end

        it "does not apply includes that are restricted to only queries in a non-only query" do
          t = Task.first
          result = @presenter_collection.presenting("tasks", :params => { :include => "restricted" }, :max_per_page => 2) { Task.where(:id => t.id) }

          expect(result['tasks'][t.id.to_s].keys).not_to include('restricted_id')
          expect(result['tasks'][Task.last.id.to_s]).not_to be_present
        end
      end

      describe "polymorphic associations" do
        it "works with polymorphic associations" do
          result = @presenter_collection.presenting("posts", :params => { :include => "subject" }) { Post.unscoped }
          expect(result['posts'][Post.first.id.to_s]).to be_present
          expect(result['workspaces'][Workspace.first.id.to_s]).to be_present
          expect(result['tasks'][Task.first.id.to_s]).to be_present
          expect(result['posts']['1']['subject_ref']).to eq({ 'id' => '1', 'key' => 'workspaces' })
          expect(result['posts']['2']['subject_ref']).to eq({ 'id' => '1', 'key' => 'tasks' })
        end

        it "uses the correct brainstem_key from the associated presenter" do
          result = @presenter_collection.presenting("posts", :params => { :include => "attachments" }) { Post.unscoped }
          expect(result['posts']['1']).to be_present
          expect(result['attachments']['1']).to be_present
          expect(result['posts']['1']['attachment_ids']).to eq ['1']
          expect(result['attachments']['1']).to_not have_key('subject_ref')
        end

        it "does not return an empty hash when none are found" do
          result = @presenter_collection.presenting("posts", :params => { :include => "subject" }) { Post.where(:id => nil) }
          expect(result).to have_key('posts')
          expect(result).not_to have_key('workspaces')
          expect(result).not_to have_key('tasks')
        end
      end
    end

    describe "handling of only" do
      it "accepts params[:only] as a list of ids to limit to" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => Workspace.limit(2).pluck(:id).join(",") }) { Workspace.unscoped }
        expect(result['workspaces'].keys).to match_array(Workspace.limit(2).pluck(:id).map(&:to_s))
      end

      it "does not paginate only requests" do
        dont_allow(@presenter_collection).paginate
        @presenter_collection.presenting("workspaces", :params => { :only => Workspace.limit(2).pluck(:id).join(",") }) { Workspace.unscoped }
      end

      it "escapes ids" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "#{Workspace.first.id}foo,;drop tables;,#{Workspace.first.id}" }) { Workspace.unscoped }
        expect(result['workspaces'].length).to eq(1)
      end

      it "only runs when it receives ids" do
        result = @presenter_collection.presenting("workspaces", :params => { :only => "" }) { Workspace.unscoped }
        expect(result['workspaces'].length).to be > 1

        result = @presenter_collection.presenting("workspaces", :params => { :only => "1" }) { Workspace.unscoped }
        expect(result['workspaces'].length).to be <= 1
      end
    end

    describe "filters" do
      before do
        WorkspacePresenter.filter(:owned_by, :integer) { |scope, user_id| scope.owned_by(user_id.to_i) }
        WorkspacePresenter.filter(:title, :string) { |scope, title| scope.where(:title => title) }
      end

      it "limits records to those matching given filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.id.to_s }) { Workspace.unscoped } # hit the API, filtering on owned_by:bob
        expect(result['workspaces']).to be_present
        expect(result['workspaces'].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }).to be_truthy # all of the returned workspaces should contain bob
      end

      it "returns all records if filters are not given" do
        result = @presenter_collection.presenting("workspaces") { Workspace.unscoped } # hit the API again, this time not filtering on anything
        expect(result['workspaces'].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }).to be_falsey # the returned workspaces no longer all contain bob
      end

      it "ignores unknown filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :wut => "is this?" }) { Workspace.unscoped }
        expect(result['workspaces'].keys.all? {|id| bob_workspaces_ids.map(&:to_s).include?(id) }).to be_falsey
      end

      it "limits records to those matching all given filters" do
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.id.to_s, :title => "bob workspace 1" }) { Workspace.unscoped } # try two filters
        expect(result['results'].first['id']).to eq(Workspace.where(:title => "bob workspace 1").first.id.to_s)
      end

      it "converts boolean parameters from strings to booleans" do
        jane_id = jane.id
        bob_id = bob.id
        WorkspacePresenter.filter(:owned_by_bob, :boolean) { |scope, boolean| boolean ? scope.where(:user_id => bob_id) : scope.where(:user_id => jane_id) }
        result = @presenter_collection.presenting("workspaces", :params => { :owned_by_bob => "false" }) { Workspace.where(nil) }
        expect(result['workspaces'].values.find { |workspace| workspace['title'].include?("jane") }).to be
        expect(result['workspaces'].values.find { |workspace| workspace['title'].include?("bob") }).not_to be
      end

      it "ensures arguments are strings if they are not arrays" do
        string = nil
        WorkspacePresenter.filter(:owned_by_bob, :boolean) do |scope, arg|
          string = arg
          scope
        end
        @presenter_collection.presenting("workspaces", :params => { :owned_by_bob => { :wut => "is this?" } }) { Workspace.where(nil) }
        expect(string).to be_truthy
      end

      it "preserves array arguments" do
        array = nil
        WorkspacePresenter.filter(:owned_by_bob, :boolean) do |scope, arg|
          array = arg
          scope
        end
        @presenter_collection.presenting("workspaces", :params => { :owned_by_bob => [1, 2] }) { Workspace.where(nil) }
        expect(array).to be_a(Array)
      end

      it "allows filters to be called with false as an argument" do
        WorkspacePresenter.filter(:nothing, :boolean) { |scope, bool| bool ? scope.where(:id => nil) : scope }
        result = @presenter_collection.presenting("workspaces", :params => { :nothing => "true" }) { Workspace.where(nil) }
        expect(result['workspaces'].length).to eq(0)
        result = @presenter_collection.presenting("workspaces", :params => { :nothing => "false" }) { Workspace.where(nil) }
        expect(result['workspaces'].length).not_to eq(0)
      end

      it "passes colon separated params through as a string" do
        a, b = nil, nil
        WorkspacePresenter.filter(:between, :string) { |scope, a_and_b|
          a, b = a_and_b.split(':')
          scope
        }

        @presenter_collection.presenting("workspaces", :params => { :between => "1:10" }) { Workspace.where(nil) }

        expect(a).to eq("1")
        expect(b).to eq("10")
      end

      it "provides helpers to the block" do
        WorkspacePresenter.helper do
          def some_method
          end
        end

        called = false
        WorkspacePresenter.filter(:something, :string) { |scope, string|
          called = true
          some_method
          scope
        }

        @presenter_collection.presenting("workspaces", :params => { :something => "hello" }) { Workspace.where(nil) }
        expect(called).to eq true
      end

      context "with defaults" do
        before do
          WorkspacePresenter.filter(:owner, :integer, :default => bob.id) { |scope, id| scope.owned_by(id) }
        end

        let(:jane) { User.where(:username => "jane").first }

        it "applies the filter when it is not requested" do
          result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
          expect(result['workspaces'].keys).to match_array(bob.workspaces.map(&:id).map(&:to_s))
        end

        it "allows falsy defaults" do
          WorkspacePresenter.filter(:include_early_workspaces, :boolean, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
          expect(result['workspaces']['2']).not_to be_present
          result = @presenter_collection.presenting("workspaces", :params => { :include_early_workspaces => "true" }) { Workspace.unscoped }
          expect(result['workspaces']['2']).to be_present
        end

        it "allows defaults to be skipped if :apply_default_filters is false" do
          WorkspacePresenter.filter(:include_early_workspaces, :boolean, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => true) { Workspace.unscoped }
          expect(result['workspaces']['2']).not_to be_present
          result = @presenter_collection.presenting("workspaces", :apply_default_filters => false) { Workspace.unscoped }
          expect(result['workspaces']['2']).to be_present
        end

        it "allows defaults set to false to be skipped if params contain :apply_default_filters with a false value" do
          WorkspacePresenter.filter(:include_early_workspaces, :boolean, :default => false) { |scope, bool| bool ? scope : scope.where("id > 3") }

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => "true" }) { Workspace.unscoped }
          expect(result['workspaces']['2']).not_to be_present

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => true }) { Workspace.unscoped }
          expect(result['workspaces']['2']).not_to be_present
        end

        it "allows defaults set to true to be skipped if params contain :apply_default_filters with a false value" do
          WorkspacePresenter.filter(:include_early_workspaces, :boolean, :default => true) { |scope, bool| bool ? scope : scope.where("id > 3") }

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => "false" }) { Workspace.unscoped }
          expect(result['workspaces']['2']).to be_present

          result = @presenter_collection.presenting("workspaces", :params => { :apply_default_filters => false }) { Workspace.unscoped }
          expect(result['workspaces']['2']).to be_present
        end

        it "allows the default value to be overridden" do
          result = @presenter_collection.presenting("workspaces", :params => { :owner => jane.id.to_s }) { Workspace.unscoped }
          expect(result['workspaces'].keys).to match_array(jane.workspaces.map(&:id).map(&:to_s))

          WorkspacePresenter.filter(:include_early_workspaces, :boolean, :default => true) { |scope, bool| bool ? scope : scope.where("id > 3") }
          result = @presenter_collection.presenting("workspaces", :params => { :include_early_workspaces => "false" }) { Workspace.unscoped }
          expect(result['workspaces']['2']).not_to be_present
        end
      end

      context "without blocks" do
        let(:bob) { User.where(:username => "bob").first }
        let(:jane) { User.where(:username => "jane").first }

        before do
          WorkspacePresenter.filter(:owned_by, :boolean, :default => bob.id)
        end

        it "calls the named scope with default arguments" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(nil) }
          expect(result['workspaces'].keys).to eq(bob.workspaces.pluck(:id).map(&:to_s))
        end

        it "calls the named scope with given arguments" do
          result = @presenter_collection.presenting("workspaces", :params => { :owned_by => jane.id.to_s }) { Workspace.where(nil) }
          expect(result['workspaces'].keys).to eq(jane.workspaces.pluck(:id).map(&:to_s))
        end

        it "can use filters without lambdas in the presenter or model, but behaves strangely when false is given" do
          WorkspacePresenter.filter(:numeric_description, :boolean)

          result = @presenter_collection.presenting("workspaces") { Workspace.where(nil) }
          expect(result['workspaces'].keys).to eq(%w[1 2 3 4])

          result = @presenter_collection.presenting("workspaces", :params => { :numeric_description => "true" }) { Workspace.where(nil) }
          expect(result['workspaces'].keys).to eq(%w[2 4])

          # This is probably not the behavior that the developer or user intends.  You should always use a one-argument lambda in your
          # model scope declaration!
          result = @presenter_collection.presenting("workspaces", :params => { :numeric_description => "false" }) { Workspace.where(nil) }
          expect(result['workspaces'].keys).to eq(%w[2 4])
        end
      end

      context "with include_params" do
        it "passes the params into the filter block" do
          WorkspacePresenter.filter(:other_filter, :integer) { |scope, opt| scope }
          WorkspacePresenter.filter(:unused_filter, :string) { |scope, opt| scope }
          WorkspacePresenter.filter(:other_filter_with_default, :boolean, default: true) { |scope, opt| scope }

          provided_params = nil

          WorkspacePresenter.filter :filter_with_param, :string, :include_params => true do |scope, option, params|
            provided_params = params
            scope
          end

          @presenter_collection.presenting("workspaces", :params => {
            :filter_with_param => "arg",
            :other_filter => 'another_arg'
          }) { Workspace.where(nil) }

          expect(provided_params).to eq({
            "filter_with_param"         => "arg",
            "other_filter"              => "another_arg",
            "other_filter_with_default" => true
          })
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
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
            expect(result['workspaces'].keys).to eq(%w[5 3])
            expect(result['count']).to eq(2)
          end

          it "calls the search block in the context of helpers" do
            called = false
            WorkspacePresenter.search { |string|
              current_user
              called = true
              [[5, 3], 2]
            }

            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
            expect(called).to eq true
          end

          it "does not apply filters" do
            mock(@presenter_collection).apply_filters_to_scope(anything, anything).times(0)
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
          end

          it "does not apply ordering" do
            mock.any_instance_of(Brainstem::Presenter).apply_ordering_to_scope(anything, anything).times(0)
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
          end

          it "does not try to handle only's" do
            mock(@presenter_collection).handle_only(anything, anything).times(0)
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
          end

          it "does not apply pagination" do
            mock(@presenter_collection).paginate(anything, anything).times(0)
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

          context "when the search results give ids that cannot be found" do
            before  do
              WorkspacePresenter.search do |string|
                [[5, 8, 3], 3]
              end
            end

            it "will generate a compacted list, without nil or 0 values" do
              result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.order("id asc") }
              expect(result['workspaces'].keys).to eq(%w[5 3])
              expect(result['count']).to eq(3)
            end
          end

          describe "passing options to the search block" do
            it "passes the search method, the search string, includes, order, and paging options" do
              WorkspacePresenter.filter(:owned_by, :integer) { |scope| scope }
              search_args = nil
              WorkspacePresenter.search do |*args|
                search_args = args
                [[1], 1] # returned ids, count - not testing this in this set of specs
              end

              @presenter_collection.presenting("workspaces", :params => { :search => "blah", :include => "tasks,lead_user", :owned_by => "false", :order => "description:desc", :page => 2, :per_page => 5 }) { Workspace.unscoped }

              string, options = search_args
              expect(string).to eq("blah")
              expect(options[:include]).to eq(["tasks", "lead_user"])
              expect(options[:owned_by]).to eq(false)
              expect(options[:order][:sort_order]).to eq("description")
              expect(options[:order][:direction]).to eq("desc")
              expect(options[:page]).to eq(2)
              expect(options[:per_page]).to eq(5)
            end

            describe "includes" do
              it "throws out requested inlcudes that the presenter does not have associations for" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :include => "users"}) { Workspace.unscoped }
                expect(search_options[:include]).to eq([])
              end
            end

            describe "filters" do
              it "passes through the default filters if no filter is requested" do
                WorkspacePresenter.filter(:owned_by, :boolean, :default => true) { |scope| scope }
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
                expect(search_options[:owned_by]).to eq(true)
              end

              it "throws out requested filters that the presenter does not have" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :highest_rated => true}) { Workspace.unscoped }
                expect(search_options[:highest_rated]).to be_nil
              end

              it "does not pass through existing non-default filters that are not requested" do
                WorkspacePresenter.filter(:owned_by, :integer) { |scope| scope }
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah"}) { Workspace.unscoped }
                expect(search_options.has_key?(:owned_by)).to eq(false)
              end
            end

            describe "orders" do
              it "passes through the default sort order if no order is requested" do
                WorkspacePresenter.default_sort_order("description:desc")
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah"}) { Workspace.unscoped }
                expect(search_options[:order][:sort_order]).to eq("description")
                expect(search_options[:order][:direction]).to eq("desc")
              end

              it "makes the sort order 'updated_at:desc' if the requested order doesn't match an existing sort order and there is no default" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :order => "created_at:asc"}) { Workspace.unscoped }
                expect(search_options[:order][:sort_order]).to eq("updated_at")
                expect(search_options[:order][:direction]).to eq("desc")
              end

              it "sanitizes sort orders" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :order => "description:owned"}) { Workspace.unscoped }
                expect(search_options[:order][:sort_order]).to eq("description")
                expect(search_options[:order][:direction]).to eq("asc")
              end
            end

            describe "pagination" do
              it "passes through limit and offset if they are requested" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :limit => 1, :offset => 2}) { Workspace.unscoped }
                expect(search_options[:limit]).to eq(1)
                expect(search_options[:offset]).to eq(2)
              end

              it "passes through only limit and offset if all pagination options are requested" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :limit => 1, :offset => 2, :per_page => 3, :page => 4}) { Workspace.unscoped }
                expect(search_options[:limit]).to eq(1)
                expect(search_options[:offset]).to eq(2)
                expect(search_options[:per_page]).to eq(nil)
                expect(search_options[:page]).to eq(nil)
              end

              it "passes through page and per_page when limit not present" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :offset => 2, :per_page => 3, :page => 4}) { Workspace.unscoped }
                expect(search_options[:limit]).to eq(nil)
                expect(search_options[:offset]).to eq(nil)
                expect(search_options[:per_page]).to eq(3)
                expect(search_options[:page]).to eq(4)
              end

              it "passes through page and per_page when offset not present" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah", :limit => 1, :per_page => 3, :page => 4}) { Workspace.unscoped }
                expect(search_options[:limit]).to eq(nil)
                expect(search_options[:offset]).to eq(nil)
                expect(search_options[:per_page]).to eq(3)
                expect(search_options[:page]).to eq(4)
              end

              it "passes through page and per_page by default" do
                search_options = nil
                WorkspacePresenter.search do |string, options|
                  search_options = options
                  [[1], 1]
                end

                @presenter_collection.presenting("workspaces", :params => { :search => "blah"}) { Workspace.unscoped }
                expect(search_options[:limit]).to eq(nil)
                expect(search_options[:offset]).to eq(nil)
                expect(search_options[:per_page]).to eq(20)
                expect(search_options[:page]).to eq(1)
              end
            end
          end
        end

        context "and there is no search request" do
          it "does not call the search method" do
            result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
            expect(result['workspaces'].keys).to eq(Workspace.pluck(:id).map(&:to_s))
          end
        end
      end

      context "without search method defined" do
        context "and a search request is made" do
          it "returns as if there was no search" do
            result = @presenter_collection.presenting("workspaces", :params => { :search => "blah" }) { Workspace.unscoped }
            expect(result['workspaces'].keys).to eq(Workspace.pluck(:id).map(&:to_s))
          end
        end
      end
    end

    describe "sorting and ordering" do
      context "when there is no sort provided" do
        it "returns an empty array when there are no objects" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => nil) }
          expect(result).to eq('count' => 0, 'meta' => { 'count' => 0, 'page_count' => 0, 'page_number' => 0, 'page_size' => 20 }, 'workspaces' => {}, 'results' => [])
        end

        it "falls back to the object's sort order when nothing is provided" do
          result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => [1, 3]) }
          expect(result['workspaces'].keys).to eq(%w[1 3])
        end
      end

      it "allows default ordering descending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(c b a 3 2 1))
      end

      it "allows default ordering ascending" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:asc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(1 2 3 a b c))
      end

      it "overrides any Arel ordering" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null").reorder('workspaces.title asc') }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(c b a 3 2 1))
      end

      it "applies orders that match the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:desc"} ) { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(c b a 3 2 1))
      end

      it "applies orders that conflict with the default order" do
        WorkspacePresenter.sort_order(:description, "workspaces.description")
        WorkspacePresenter.default_sort_order("description:desc")
        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:asc"} ) { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(1 2 3 a b c))
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
        expect(result.keys).to match_array %w[count meta workspaces results]

        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:;;hacker;;" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('asc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:desc" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('desc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "description:asc" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('asc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "drop table:desc" }) { Workspace.where("id is not null") }
        expect(last_direction).to eq('desc')

        result = @presenter_collection.presenting("workspaces", :params => { :order => "title:desc" }) { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['title'] }).to eq(["jane workspace 2", "jane workspace 1", "bob workspace 4", "bob workspace 3", "bob workspace 2", "bob workspace 1"])

        result = @presenter_collection.presenting("workspaces", :params => { :order => "title:hacker" }) { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['title'] }).to eq(["bob workspace 1", "bob workspace 2", "bob workspace 3", "bob workspace 4", "jane workspace 1", "jane workspace 2"])

        result = @presenter_collection.presenting("workspaces", :params => { :order => "title:;;;drop table;;" }) { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['title'] }).to eq(["bob workspace 1", "bob workspace 2", "bob workspace 3", "bob workspace 4", "jane workspace 1", "jane workspace 2"])
      end

      it "can take a proc" do
        WorkspacePresenter.sort_order(:id) { |scope, direction| scope.order("workspaces.id #{direction}") }
        WorkspacePresenter.default_sort_order("id:asc")

        # Default
        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(a 1 b 2 c 3))

        # Asc
        result = @presenter_collection.presenting("workspaces", :params => { :order => "id:asc" }) { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(a 1 b 2 c 3))

        # Desc
        result = @presenter_collection.presenting("workspaces", :params => { :order => "id:desc" }) { Workspace.where("id is not null") }
        expect(result['results'].map {|i| result['workspaces'][i['id']]['description'] }).to eq(%w(3 c 2 b 1 a))
      end

      it "runs procs in the context of any provided helpers" do
        WorkspacePresenter.helper do
          def some_method
          end
        end

        called = false
        WorkspacePresenter.sort_order(:id) { |scope, direction| some_method; called = true; scope.order("workspaces.id #{direction}") }
        WorkspacePresenter.default_sort_order("id:asc")

        result = @presenter_collection.presenting("workspaces") { Workspace.where("id is not null") }
        expect(called).to be true
      end
    end

    describe "the :as option" do
      it "is no longer supported" do
        expect(lambda {
          @presenter_collection.presenting("workspaces", as: :my_workspaces) { Workspace.where(:id => 1) }
        }).to raise_error(/brainstem_key annotation/)
      end
    end

    describe "the count top level key" do
      it "should return the total number of matched records" do
        WorkspacePresenter.filter(:owned_by, :integer) { |scope, user_id| scope.owned_by(user_id.to_i) }

        result = @presenter_collection.presenting("workspaces") { Workspace.where(:id => 1) }
        expect(result['count']).to eq(1)

        result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
        expect(result['count']).to eq(Workspace.count)

        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.to_param }) { Workspace.unscoped }
        expect(result['count']).to eq(Workspace.owned_by(bob.to_param).count)

        result = @presenter_collection.presenting("workspaces", :params => { :owned_by => bob.to_param }) { Workspace.group(:id) }
        expect(result['count']).to eq(Workspace.owned_by(bob.to_param).count)
      end
    end

    describe "providing a specific Presenter with the :primary_presenter option" do
      it "overrides the infered presenter" do
        some_presenter_klass = Class.new(WorkspacePresenter) do
          fields do
            field :secret_info, :string
          end
        end

        result = @presenter_collection.presenting("workspaces", primary_presenter: some_presenter_klass.new) { Workspace.where(id: 1) }
        expect(result['workspaces']['1']['secret_info']).to eq(Workspace.find(1).secret_info)
      end
    end

    describe "when optional fields exist" do
      it 'does not include optional field by default' do
        result = @presenter_collection.presenting("workspaces") { Workspace.unscoped }
        workspaces = result['workspaces'].values
        expect(workspaces.any? {|w| w.has_key?('expensive_title') }).to be_falsey
        expect(workspaces.any? {|w| w.has_key?('expensive_title2') }).to be_falsey
        expect(workspaces.any? {|w| w.has_key?('expensive_title3') }).to be_falsey
      end

      it 'includes the optional field when explicitly requested' do
        result = @presenter_collection.presenting("workspaces", :params => { :optional_fields => 'expensive_title,expensive_title2' }) { Workspace.unscoped }
        workspaces = result['workspaces'].values
        expect(workspaces.all? {|w| w.has_key?('expensive_title') }).to be_truthy
        expect(workspaces.all? {|w| w.has_key?('expensive_title2') }).to be_truthy
        expect(workspaces.any? {|w| w.has_key?('expensive_title3') }).to be_falsey
      end

      it 'ignores unknown fields' do
        mock.proxy.any_instance_of(Brainstem::Presenter).group_present(anything, [], { optional_fields: ['expensive_title', 'expensive_title2'], load_associations_into: {} })
        @presenter_collection.presenting("workspaces", :params => { :optional_fields => 'expensive_title , expensive_title2,foo' }) { Workspace.unscoped }
      end
    end
  end

  describe '#structure_response' do
    let(:options) { {params: {}, primary_presenter: @presenter_collection.for!(Workspace) } }
    let(:response_body) { @presenter_collection.structure_response(Workspace, Workspace.all, strategy, 17, options) }
    let(:strategy) { OpenStruct.new(calculate_per_page: 25) }

    it 'has a count' do
      expect(response_body['count']).to eq(17)
    end

    it 'has a list of results' do
      expect(response_body['results'].length).to eq(Workspace.count)

      response_body['results'].each do |result|
        expect(result['key']).to eq('workspaces')
        expect(result['id'].to_i).not_to eq(0)
      end
    end

    it 'has id-attributes maps for all objects' do
      response_body['results'].each do |result|
        expect(response_body[result['key']][result['id']]).not_to be_empty
      end
    end
  end

  describe "#validate!" do
    it 'should raise an error when a presenter is invalid' do
      WorkspacePresenter.fields do
        field :title, :string, if: [:wat]
        field :oh_noes, :string
      end
      expect(lambda { Brainstem.presenter_collection.validate! }).to raise_error(/Workspace: Fields 'oh_noes' is not valid because/)
    end

    describe 'checking out spec fixtures' do
      specify 'they should be valid' do
        expect(lambda { Brainstem.presenter_collection.validate! }).to_not raise_error
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

      it "returns a new instance of the presenter class each time" do
        presenter1 = Brainstem.presenter_collection("v1").for(Array)
        presenter2 = Brainstem.presenter_collection("v1").for(Array)
        expect(presenter1).not_to eq presenter2
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
        expect { Brainstem.presenter_collection("v1").for!(String) }.to raise_error(ArgumentError)
      end
    end

    describe "brainstem_key_for! method" do
      class AnotherWorkspace < Workspace
      end

      let!(:another_workspace_presenter_class) do
        Class.new(Brainstem::Presenter) do
          presents AnotherWorkspace
        end
      end

      it "defaults to the table name" do
        expect(Brainstem.presenter_collection.for!(AnotherWorkspace)).to be_a(another_workspace_presenter_class)
        expect(Brainstem.presenter_collection.brainstem_key_for!(AnotherWorkspace)).to eq 'workspaces'
      end

      it "uses the given brainstem_key if present" do
        another_workspace_presenter_class.brainstem_key(:projects)
        expect(Brainstem.presenter_collection.brainstem_key_for!(AnotherWorkspace)).to eq 'projects'
      end

      it "raises if there is no presenter for the given class" do
        expect { Brainstem.presenter_collection("v1").brainstem_key_for!(String) }.to raise_error(ArgumentError)
      end
    end
  end
end
