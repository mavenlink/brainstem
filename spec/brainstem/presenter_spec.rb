require 'spec_helper'

describe Brainstem::Presenter do
  describe "class behavior" do
    describe "implicit namespacing" do
      module V1
        class SomePresenter < Brainstem::Presenter
        end
      end

      it "uses the closest module name as the presenter namespace" do
        V1::SomePresenter.presents String
        expect(Brainstem.presenter_collection(:v1).for(String)).to be_a(V1::SomePresenter)
      end

      it "does not map namespaced presenters into the default namespace" do
        V1::SomePresenter.presents String
        expect(Brainstem.presenter_collection.for(String)).to be_nil
      end
    end

    describe '.presents' do
      let!(:presenter_class) { Class.new(Brainstem::Presenter) }

      it 'records itself as the presenter for the given class' do
        presenter_class.presents String
        expect(Brainstem.presenter_collection.for(String)).to be_a(presenter_class)
      end

      it 'records itself as the presenter for the given classes' do
        presenter_class.presents String, Array
        expect(Brainstem.presenter_collection.for(String)).to be_a(presenter_class)
        expect(Brainstem.presenter_collection.for(Array)).to be_a(presenter_class)
      end

      it 'can be called more than once' do
        presenter_class.presents String
        presenter_class.presents Array
        expect(Brainstem.presenter_collection.for(String)).to be_a(presenter_class)
        expect(Brainstem.presenter_collection.for(Array)).to be_a(presenter_class)
      end

      it 'returns the set of presented classes' do
        expect(presenter_class.presents(String)).to eq([String])
        expect(presenter_class.presents(Array)).to eq([String, Array])
        expect(presenter_class.presents).to eq([String, Array])
      end

      it 'should not be inherited' do
        presenter_class.presents(String)
        expect(presenter_class.presents).to eq [String]
        subclass = Class.new(presenter_class)
        expect(subclass.presents).to eq []
        subclass.presents(Array)
        expect(subclass.presents).to eq [Array]
        expect(presenter_class.presents).to eq [String]
      end

      it 'raises an error when given a string' do
        expect(lambda {
          presenter_class.presents 'Array'
        }).to raise_error(/Brainstem Presenter#presents now expects a Class instead of a class name/)
      end
    end
  end

  describe "#group_present" do
    let(:presenter_class) do
      Class.new(Brainstem::Presenter) do
        presents Workspace

        helper do
          def helper_method(model)
            Task.where(:workspace_id => model.id)[0..1]
          end
        end

        fields do
          field :updated_at, :datetime
        end

        associations do
          association :tasks, Task
          association :user, User
          association :something, User, via: :user
          association :lead_user, User
          association :lead_user_with_lambda, User, dynamic: lambda { |model| model.user }
          association :tasks_with_lambda, Task, dynamic: lambda { |model| Task.where(:workspace_id => model.id) }
          association :tasks_with_helper_lambda, Task, dynamic: lambda { |model| helper_method(model) }
          association :synthetic, :polymorphic
        end
      end
    end
    
    let(:workspace) { Workspace.find_by_title("bob workspace 1") }
    let(:presenter) { presenter_class.new }

    describe "the field DSL" do
      let(:presenter) { WorkspacePresenter.new }
      let(:model) { Workspace.find(1) }

      it 'calls named methods' do
        expect(presenter.group_present([model]).first['title']).to eq model.title
      end

      it 'can call methods with :via' do
        presenter.configuration[:fields][:title].options[:via] = :description
        expect(presenter.group_present([model]).first['title']).to eq model.description
      end

      it 'can call a dynamic lambda' do
        expect(presenter.group_present([model]).first['dynamic_title']).to eq "title: #{model.title}"
      end

      it 'handles nesting' do
        expect(presenter.group_present([model]).first['permissions']['access_level']).to eq 2
      end

      describe 'handling of conditional fields' do
        it 'does not return conditional fields when their :if conditionals do not match' do
          expect(presenter.group_present([model]).first['secret']).to be_nil
          expect(presenter.group_present([model]).first['bob_title']).to be_nil
        end

        it 'returns conditional fields when their :if matches' do
          model.title = 'hello'
          expect(presenter.group_present([model]).first['hello_title']).to eq 'title is hello'
        end

        it 'returns fields with the :if option only when all of the conditionals in that :if are true' do
          model.title = 'hello'
          presenter.class.helper do
            def current_user
              'not bob'
            end
          end
          expect(presenter.group_present([model]).first['secret']).to be_nil
          presenter.class.helper do
            def current_user
              'bob'
            end
          end
          expect(presenter.group_present([model]).first['secret']).to eq model.secret_info
        end
      end
    end

    describe "adding object ids as strings" do
      before do
        post_presenter = Class.new(Brainstem::Presenter) do
          presents Post

          fields do
            field :body, :string
          end
        end

        @presenter = post_presenter.new
        @post = Post.first
      end

      it "outputs the associated object's id and type" do
        data = @presenter.group_present([@post]).first
        expect(data['id']).to eq(@post.id.to_s)
        expect(data['body']).to eq(@post.body)
      end
    end

    describe "converting dates and times" do
      it "should convert all Time-and-date-like objects to iso8601" do
        presenter = Class.new(Brainstem::Presenter) do
          fields do
            field :time, :datetime, dynamic: lambda { Time.now }
            field :date, :date, dynamic: lambda { Date.new }
            fields :recursion do
              field :time, :datetime, dynamic: lambda { Time.now }
              field :something, :datetime, dynamic: lambda { [Time.now, :else] }
              field :foo, :string, dynamic: lambda { :bar }
            end
          end
        end

        iso8601_time = /\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}[-+]\d{2}:\d{2}/
        iso8601_date = /\d{4}-\d{2}-\d{2}/

        struct = presenter.new.group_present([Workspace.first]).first
        expect(struct['time']).to match(iso8601_time)
        expect(struct['date']).to match(iso8601_date)
        expect(struct['recursion']['time']).to match(iso8601_time)
        expect(struct['recursion']['something'].first).to match(iso8601_time)
        expect(struct['recursion']['something'].last).to eq(:else)
        expect(struct['recursion']['foo']).to eq(:bar)
      end
    end

    describe "outputting associations" do
      it "should not convert or return non-included associations, but should return <association>_id for belongs_to relationships, plus all fields" do
        json = presenter.group_present([workspace], []).first
        expect(json.keys).to match_array %w[id updated_at something_id user_id]
      end

      it "should convert requested has_many associations (includes) into the <association>_ids format" do
        expect(workspace.tasks.length).to be > 0
        expect(presenter.group_present([workspace], ['tasks']).first['task_ids']).to match_array(workspace.tasks.map(&:id).map(&:to_s))
      end

      it "should ignore unknown associations" do
        result = presenter.group_present(Workspace.all.to_a, ['tasks', 'unknown'])
        expect(result.length).to eq Workspace.count
        expect(result.last['task_ids']).to eq Workspace.last.tasks.pluck(:id).map(&:to_s)
      end

      it "should allow has_many associations to work on groups of models" do
        result = presenter.group_present(Workspace.all.to_a, ['tasks'])
        expect(result.length).to eq Workspace.count
        first_workspace_tasks = Workspace.first.tasks.pluck(:id).map(&:to_s)
        last_workspace_tasks = Workspace.last.tasks.pluck(:id).map(&:to_s)
        expect(last_workspace_tasks.length).to eq 1
        expect(result.last['task_ids']).to eq last_workspace_tasks
        expect(result.first['task_ids']).to eq first_workspace_tasks
      end

      it "should convert requested belongs_to and has_one associations into the <association>_id format when requested" do
        expect(presenter.group_present([workspace], ['user']).first['user_id']).to eq(workspace.user.id.to_s)
      end

      it "converts non-association models into <model>_id format when they are requested" do
        expect(presenter.group_present([workspace], ['lead_user']).first['lead_user_id']).to eq(workspace.lead_user.id.to_s)
      end

      it "handles associations provided with lambdas" do
        expect(presenter.group_present([workspace], ['lead_user_with_lambda']).first['lead_user_with_lambda_id']).to eq(workspace.lead_user.id.to_s)
        expect(presenter.group_present([workspace], ['tasks_with_lambda']).first['tasks_with_lambda_ids']).to eq(workspace.tasks.map(&:id).map(&:to_s))
      end

      it "handles helpers method calls in association lambdas" do
        expect(presenter.group_present([workspace], ['tasks_with_helper_lambda']).first['tasks_with_helper_lambda_ids']).to eq(workspace.tasks.map(&:id).map(&:to_s)[0..1])
      end

      it "should return <association>_id fields when the given association ids exist on the model whether it is requested or not" do
        expect(presenter.group_present([workspace], ['user']).first['user_id']).to eq(workspace.user_id.to_s)

        json = presenter.group_present([workspace], []).first
        expect(json.keys).to match_array %w[user_id something_id id updated_at]
        expect(json['user_id']).to eq(workspace.user_id.to_s)
        expect(json['something_id']).to eq(workspace.user_id.to_s)
      end

      it "should return null, not empty string when ids are missing" do
        workspace.user = nil
        workspace.tasks = []
        expect(presenter.group_present([workspace], ['lead_user_with_lambda']).first['lead_user_with_lambda_id']).to eq(nil)
        expect(presenter.group_present([workspace], ['user']).first['user_id']).to eq(nil)
        expect(presenter.group_present([workspace], ['something']).first['something_id']).to eq(nil)
        expect(presenter.group_present([workspace], ['tasks']).first['task_ids']).to eq([])
      end

      describe "polymorphic associations" do
        before do
          some_presenter = Class.new(Brainstem::Presenter) do
            presents Post

            fields do
              field :body, :string
            end

            associations do
              association :subject, :polymorphic
              association :another_subject, :polymorphic, via: :subject
              association :forced_model, Workspace, via: :subject
            end
          end

          @presenter = some_presenter.new
        end

        let(:presented_data) { @presenter.group_present([post]).first }

        context "when polymorphic association exists" do
          let(:post) { Post.find(1) }

          it "outputs the object as a hash with the id & class table name" do
            expect(presented_data['subject_ref']).to eq({ 'id' => post.subject.id.to_s,
                                                          'key' => post.subject.class.table_name })
          end

          it "outputs custom names for the object as a hash with the id & class table name" do
            expect(presented_data['another_subject_ref']).to eq({ 'id' => post.subject.id.to_s,
                                                                  'key' => post.subject.class.table_name })
          end

          it "skips the polymorphic handling when a model is given" do
            expect(presented_data['forced_model_id']).to eq(post.subject.id.to_s)
            expect(presented_data).not_to have_key('forced_model_type')
            expect(presented_data).not_to have_key('forced_model_ref')
          end
        end

        context "when polymorphic association does not exist" do
          let(:post) { Post.find(3) }

          it "outputs nil" do
            expect(presented_data['subject_ref']).to be_nil
          end

          it "outputs nil" do
            expect(presented_data['another_subject_ref']).to be_nil
          end
        end
      end

      context "when the model has an <association>_id method but no column" do
        it "does not include the <association>_id field" do
          def workspace.synthetic_id
            raise "this explodes because it's not an association"
          end
          expect(presenter.group_present([workspace], []).first).not_to have_key('synthetic_id')
        end
      end
    end

    describe "preloading" do
      it "preloads associations when they are full model-level associations" do
        mock(Brainstem::Presenter).ar_preload(anything, anything) do |models, args|
          expect(args).to eq %w[tasks user]
        end
        result = presenter.group_present(Workspace.order('id desc'), %w[tasks user lead_user tasks_with_lambda])
      end
      
      it "includes any associations declared via the preload DSL directive" do
        presenter_class.preload :posts

        mock(Brainstem::Presenter).ar_preload(anything, anything) do |models, args|
          expect(args).to eq ['tasks', :posts]
        end

        result = presenter.group_present(Workspace.order('id desc'), %w[tasks lead_user tasks_with_lambda])
      end

      it "includes any string associations declared via the preload DSL directive" do
        presenter_class.preload 'user'

        mock(Brainstem::Presenter).ar_preload(anything, anything) do |models, args|
          expect(args).to eq %w[tasks user]
        end

        result = presenter.group_present(Workspace.order('id desc'), %w[tasks user lead_user tasks_with_lambda])
      end
    end
  end

  describe "#extract_filters" do
    let(:presenter_class) { WorkspacePresenter }
    let(:presenter) { presenter_class.new }

    it 'returns only known filters' do
      presenter_class.filter :owned_by
      presenter_class.filter(:bar) { |scope| scope }
      expect(presenter.extract_filters({ 'foo' => 'hi' })).to eq({})
      expect(presenter.extract_filters({ 'owned_by' => '2' })).to eq({ 'owned_by' => '2' })
    end

    it "converts 'true' and 'false' into true and false" do
      presenter_class.filter :owned_by
      expect(presenter.extract_filters({ 'owned_by' => 'true' })).to eq({ 'owned_by' => true })
      expect(presenter.extract_filters({ 'owned_by' => 'false' })).to eq({ 'owned_by' => false })
      expect(presenter.extract_filters({ 'owned_by' => 'hi' })).to eq({ 'owned_by' => 'hi' })
    end

    it 'defaults to applying default filters' do
      presenter_class.filter :owned_by, default: '2'
      expect(presenter.extract_filters({ 'owned_by' => '3' })).to eq({ 'owned_by' => '3' })
      expect(presenter.extract_filters({})).to eq({ 'owned_by' => '2' })
    end

    it 'will skip default filters when asked' do
      presenter_class.filter :owned_by, default: '2'
      expect(presenter.extract_filters({ 'owned_by' => '3' }, apply_default_filters: false)).to eq({ 'owned_by' => '3' })
      expect(presenter.extract_filters({}, apply_default_filters: false)).to eq({})
    end

    it 'ignores nil and blank values' do
      presenter_class.filter :owned_by
      expect(presenter.extract_filters({ 'owned_by' => nil })).to eq({})
      expect(presenter.extract_filters({ 'owned_by' => '' })).to eq({})
    end
  end

  describe "#apply_filters_to_scope" do
    let(:presenter_class) { WorkspacePresenter }
    let(:presenter) { presenter_class.new }
    let(:scope) { Workspace.where(nil) }
    let(:params) { { 'bar' => 'foo' } }
    let(:options) { { apply_default_filters: true } }

    before do
      presenter_class.filter :owned_by, default: '2'
      presenter_class.filter(:bar) { |scope| scope.where(id: 6) }
      mock(presenter).extract_filters(params, options) { { 'bar' => 'foo', 'owned_by' => '2' } }
    end

    it 'extracts valid filters from the params' do
      presenter.apply_filters_to_scope(scope, params, options)
    end

    it 'runs lambdas in the scope of the helper instance' do
      expect(presenter.apply_filters_to_scope(scope, params, options).to_sql).to match(/id.\s*=\s*6/)
    end

    it 'sends symbols to the scope' do
      expect(presenter.apply_filters_to_scope(scope, params, options).to_sql).to match(/id.\s*=\s*2/)
    end
  end

  describe "#apply_ordering_to_scope" do
    let(:presenter_class) { WorkspacePresenter }
    let(:presenter) { presenter_class.new }
    let(:scope) { Workspace.where(nil) }

    it 'uses #calculate_sort_name_and_direction to extract a sort name and direction from user params' do
      presenter_class.sort_order :title, "workspaces.title"
      mock(presenter).calculate_sort_name_and_direction('order' => 'title:desc') { ['title', 'desc'] }
      presenter.apply_ordering_to_scope(scope, 'order' => 'title:desc')
    end

    it 'runs procs in the context of any helpers' do
      presenter_class.helper do
        def some_method
        end
      end

      direction = nil
      presenter_class.sort_order(:title) do |scope, d|
        some_method
        direction = d
        scope
      end
      presenter.apply_ordering_to_scope(scope, 'order' => 'title:asc')
      expect(direction).to eq 'asc'
    end

    it 'applies the named ordering in the given direction' do
      direction = nil
      presenter_class.sort_order :title, 'workspaces.title'
      expect(presenter.apply_ordering_to_scope(scope, 'order' => 'title:asc').to_sql).to match(/order by workspaces.title asc/i)
    end
  end

  describe "#calculate_sort_name_and_direction" do
    let(:presenter_class) { WorkspacePresenter }
    let(:presenter) { presenter_class.new }

    it 'uses default_sort_order by default when present' do
      presenter_class.default_sort_order 'foo:asc'
      expect(presenter.calculate_sort_name_and_direction).to eq ['foo', 'asc']
    end

    it 'uses updated_at:desc when no default has been set' do
      expect(presenter.calculate_sort_name_and_direction).to eq ['updated_at', 'desc']
    end

    it 'ignores unknown sorts' do
      presenter_class.sort_order :foo, 'workspaces.foo'
      expect(presenter.calculate_sort_name_and_direction('order' => 'hello:desc')).to eq ['updated_at', 'desc']
      expect(presenter.calculate_sort_name_and_direction('order' => 'foo:desc')).to eq ['foo', 'desc']
    end

    it 'sanitizes the direction' do
      presenter_class.sort_order :foo, 'workspaces.foo'
      expect(presenter.calculate_sort_name_and_direction('order' => 'foo:drop table')).to eq ['foo', 'asc']
      expect(presenter.calculate_sort_name_and_direction('order' => 'foo:')).to eq ['foo', 'asc']
      expect(presenter.calculate_sort_name_and_direction('order' => 'foo:hi')).to eq ['foo', 'asc']
      expect(presenter.calculate_sort_name_and_direction('order' => 'foo:DESCE')).to eq ['foo', 'asc']
      expect(presenter.calculate_sort_name_and_direction('order' => 'foo:asc')).to eq ['foo', 'asc']
      expect(presenter.calculate_sort_name_and_direction('order' => 'foo:;;;droptable::;;')).to eq ['foo', 'asc']
    end
  end

  describe '#allowed_associations' do
    let(:presenter_class) do
      Class.new(Brainstem::Presenter) do
        associations do
          association :user, User
          association :workspace, Workspace
          association :task, Task, restrict_to_only: true
        end
      end
    end

    let(:presenter_instance) { presenter_class.new }

    it 'returns all associations that are not restrict_to_only' do
      expect(presenter_instance.allowed_associations(is_only_query = false).keys).to match_array %w[user workspace]
    end

    it 'returns associations that are restrict_to_only if is_only_query is true' do
      expect(presenter_instance.allowed_associations(is_only_query = true).keys).to match_array %w[user workspace task]
    end
  end
end
