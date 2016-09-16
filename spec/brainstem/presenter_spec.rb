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
        expect(Brainstem.presenter_collection('v1').for(String)).to be_a(V1::SomePresenter)
        expect(V1::SomePresenter.namespace).to eq 'v1'
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

      it 'removes duplicates when called more then once' do
        expect(presenter_class.presents(Array)).to eq([Array])
        expect(presenter_class.presents(Array, Array)).to eq([Array])
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
          association :missing_user, User
          association :something, User, via: :user
          association :lead_user, User
          association :lead_user_with_lambda, User, dynamic: lambda { |model| model.user }
          association :tasks_with_lambda, Task, dynamic: lambda { |model| Task.where(:workspace_id => model.id) }
          association :tasks_with_helper_lambda, Task, dynamic: lambda { |model| helper_method(model) }
          association :tasks_with_lookup, Task, lookup: lambda { |models| Task.where(workspace_id: models.map(&:id)).group_by { |task| task.workspace_id } }
          association :tasks_with_lookup_fetch, Task,
                      lookup: lambda { |models| Task.where(workspace_id: models.map(&:id)).group_by { |task| task.workspace_id } },
                      lookup_fetch: lambda { |lookup, model| lookup[model.id] }
          association :synthetic, :polymorphic
        end
      end
    end
    
    let(:workspace) { Workspace.find_by_title("bob workspace 1") }
    let(:presenter) { presenter_class.new }

    describe "the field DSL" do
      let(:presenter_class) { Class.new(WorkspacePresenter) }
      let(:presenter) { presenter_class.new }
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

      it 'can call a lookup lambda' do
        expect(presenter.group_present([model]).first['lookup_title']).to eq "lookup_title: #{model.title}"
      end

      it 'can call a lookup_fetch lambda' do
        expect(presenter.group_present([model]).first['lookup_fetch_title']).to eq "lookup_fetch_title: #{model.title}"
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

        describe "caching of conditional evaluations" do
          it 'only runs model conditionals once per model' do
            model_id_call_count = { 1 => 0, 2 => 0 }

            presenter_class.conditionals do
              model :model_id_is_two, lambda { |model| model_id_call_count[model.id] += 1; model.id == 2 }
            end

            presenter_class.fields do
              field :only_on_model_two, :string,
                    dynamic: lambda { "some value" },
                    if: :model_id_is_two
              field :another_only_on_model_two, :string,
                    dynamic: lambda { "some value" },
                    if: :model_id_is_two
            end

            results = presenter.group_present([Workspace.find(1), Workspace.find(2)])
            expect(results.first['only_on_model_two']).not_to be_present
            expect(results.last['only_on_model_two']).to be_present
            expect(results.first['another_only_on_model_two']).not_to be_present
            expect(results.last['another_only_on_model_two']).to be_present
            expect(results.first['id']).to eq '1'
            expect(results.last['id']).to eq '2'

            expect(model_id_call_count).to eq({ 1 => 1, 2 => 1 })
          end

          it 'only runs request conditionals once per request' do
            call_count = 0

            presenter_class.conditionals do
              request :new_request_conditional, lambda { call_count += 1 }
            end

            presenter_class.fields do
              field :new_field, :string,
                    dynamic: lambda { "new_field value" },
                    if: :new_request_conditional
              field :new_field2, :string,
                    dynamic: lambda { "new_field2 value" },
                    if: :new_request_conditional
            end

            presenter.group_present([Workspace.find(1), Workspace.find(2)])

            expect(call_count).to eq 1
          end
        end
      end

      describe 'helpers in dynamic fields' do
        let(:presenter_class) do
          Class.new(Brainstem::Presenter) do
            helper do
              def counter
                @count ||= 0
                @count += 1
              end
            end

            fields do
              field :memoized_helper_value1, :integer, dynamic: lambda { |model| counter }
              field :memoized_helper_value2, :integer, dynamic: lambda { |model| counter }
              field :memoized_helper_value3, :integer, dynamic: lambda { |model| counter }
              field :memoized_helper_value4, :integer, dynamic: lambda { |model| counter }
            end
          end
        end

        let(:presenter) { presenter_class.new }

        it 'shares the helper instance across fields, but not across instances' do
          fields = presenter.group_present([model, model])
          expect(fields[0].slice(*%w[memoized_helper_value1 memoized_helper_value2 memoized_helper_value3 memoized_helper_value4]).values).to match_array [1, 2, 3, 4]
          expect(fields[1].slice(*%w[memoized_helper_value1 memoized_helper_value2 memoized_helper_value3 memoized_helper_value4]).values).to match_array [1, 2, 3, 4]
        end
      end

      describe 'handling of optional fields' do
        it 'does not include optional fields by default' do
          expect(presenter.group_present([model]).first).not_to have_key('expensive_title')
        end

        it 'includes optional fields when explicitly requested' do
          presented_workspace = presenter.group_present([model], [], optional_fields: ['expensive_title', 'expensive_title2']).first

          expect(presented_workspace).to have_key('expensive_title')
          expect(presented_workspace).to have_key('expensive_title2')
          expect(presented_workspace).not_to have_key('expensive_title3')
        end

        context 'handling of conditional' do
          it 'does not include field when condition is not met' do
            model.title = 'Not hello'
            presented_workspace = presenter.group_present([model], [], optional_fields: ['conditional_expensive_title']).first
            expect(presented_workspace).not_to have_key('conditional_expensive_title')
          end

          it 'includes field when condition is met' do
            model.title = 'hello'
            presented_workspace = presenter.group_present([model], [], optional_fields: ['conditional_expensive_title']).first
            expect(presented_workspace).to have_key('conditional_expensive_title')
          end
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

      it "should convert requested belongs_to and has_one associations into the <association>_id format when requested, even if they're not found" do
        expect(presenter.group_present([workspace], ['missing_user']).first).to have_key('missing_user_id')
        expect(presenter.group_present([workspace], ['missing_user']).first['missing_user_id']).to eq(nil)
      end

      it "converts non-association models into <model>_id format when they are requested" do
        expect(presenter.group_present([workspace], ['lead_user']).first['lead_user_id']).to eq(workspace.lead_user.id.to_s)
      end

      it "handles associations provided with lambdas" do
        expect(presenter.group_present([workspace], ['lead_user_with_lambda']).first['lead_user_with_lambda_id']).to eq(workspace.lead_user.id.to_s)
        expect(presenter.group_present([workspace], ['tasks_with_lambda']).first['tasks_with_lambda_ids']).to eq(workspace.tasks.map(&:id).map(&:to_s))
      end

      it "handles associations provided with a lookup" do
        expect(presenter.group_present([workspace], ['tasks_with_lookup']).first['tasks_with_lookup_ids']).to eq(workspace.tasks.map(&:id).map(&:to_s))
      end

      it "handles associations provided with a lookup_fetch" do
        expect(presenter.group_present([workspace], ['tasks_with_lookup_fetch']).first['tasks_with_lookup_fetch_ids']).to eq(workspace.tasks.map(&:id).map(&:to_s))
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
        let(:some_presenter) do
          Class.new(Brainstem::Presenter) do
            presents Post

            fields do
              field :body, :string
            end

            associations do
              association :subject, :polymorphic
              association :another_subject, :polymorphic, via: :subject
              association :forced_model, Workspace, via: :subject
              association :things, :polymorphic
            end
          end
        end

        let(:presenter) { some_presenter.new }

        context "when asking for the association" do
          let(:presented_data) { presenter.group_present([post], %w[subject another_subject forced_model things]).first }

          context "when polymorphic association exists" do
            let(:post) { Post.find(1) }

            it "outputs the object as a hash with the id & class table name" do
              expect(presented_data['subject_ref']).to eq({ 'id' => post.subject.id.to_s,
                                                            'key' => 'workspaces' })
            end

            it "outputs custom names for the object as a hash with the id & class table name" do
              expect(presented_data['another_subject_ref']).to eq({ 'id' => post.subject.id.to_s,
                                                                    'key' => 'workspaces' })
            end

            context "presenting a mixture of things" do
              it 'will return a *_refs array' do
                expect(presented_data['thing_refs']).to eq [
                                                             { 'id' => '1', 'key' => 'workspaces' },
                                                             { 'id' => '1', 'key' => 'posts' },
                                                             { 'id' => '1', 'key' => 'tasks' }
                                                           ]
              end
            end

            context "for STI targets" do
              let(:post) { Post.create!(subject: Attachments::PostAttachment.first, user: User.first, body: '1 2 3') }

              it "uses the brainstem_key from the presenter" do
                expect(presented_data['subject_ref']).to eq({ 'id' => post.subject_id.to_s,
                                                              'key' => 'attachments' })
              end

              it "uses the correct namespace when finding a presenter" do
                module V2
                  class NewPostPresenter < Brainstem::Presenter
                    presents Post

                    associations do
                      association :subject, :polymorphic
                    end
                  end
                end

                expect {
                  V2::NewPostPresenter.new.group_present([post], %w[subject]).first
                }.to raise_error(/Unable to find a presenter for class Attachments::PostAttachment/)
              end
            end

            it "skips the polymorphic handling when a model is given" do
              expect(presented_data['forced_model_id']).to eq(post.subject.id.to_s)
              expect(presented_data).not_to have_key('forced_model_type')
              expect(presented_data).not_to have_key('forced_model_ref')
            end

            describe "the legacy :always_return_ref_with_sti_base option" do
              before do
                some_presenter.associations do
                  association :always_subject, :polymorphic, via: :subject,
                              always_return_ref_with_sti_base: true
                end
              end

              let(:post) { Post.create!(subject: Attachments::PostAttachment.first, user: User.first, body: '1 2 3') }

              describe 'when the presenter can be found' do
                before do
                  Class.new(Brainstem::Presenter) do
                    presents Attachments::Base

                    brainstem_key :foo
                  end
                end

                it "always returns the *_ref object, even when not included" do
                  expect(presented_data['always_subject_ref']).to eq({ 'id' => post.subject.id.to_s,
                                                                       'key' => 'foo' })
                end
              end

              # It tries to find the key based on the *_type value in the DB (which will be the STI base class, and may error if no presenter exists)
              describe 'when the presenter cannot be found' do
                it "raises an error" do
                  expect { presented_data['always_subject_ref'] }.to raise_error(/Unable to find a presenter for class Attachments::Base/)
                end
              end
            end
          end

          context "when polymorphic association does not exist" do
            let(:post) { Post.find(3) }

            it "outputs nil" do
              expect(presented_data).to have_key('subject_ref')
              expect(presented_data['subject_ref']).to be_nil
            end

            it "outputs nil" do
              expect(presented_data).to have_key('another_subject_ref')
              expect(presented_data['another_subject_ref']).to be_nil
            end
          end
        end

        context "when not asking for the association" do
          let(:presented_data) { presenter.group_present([post]).first }
          let(:post) { Post.find(1) }

          it "does not include the reference" do
            expect(presented_data).to_not have_key('subject_ref')
            expect(presented_data).to_not have_key('another_subject_ref')
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

      #
      # We have three strategies for introspecting what the AR Preloader
      # receives:
      #
      # 1. Actually looking at what AR receives.
      #
      #    This is sub-optimal because AR works differently between versions
      #    3 and 4, so introspecting is difficult.
      #
      # 2. Looking at what the proc that encapsulates the AR methods is
      #    called with.
      #
      #    This is difficult to do because we don't control the instantiation
      #    of the Preloader, which makes injecting this hard.
      #
      # 3. Intercept the instantiating parent function and append the
      #    inspectable proc.
      #
      #    This is probably the grossest of all the above options, and I
      #    suspect it's the greatest indication that we're testing
      #    inappropriately here -- a fact that I think bears weight given
      #    we're making unit-level assertions in an integration spec.
      #    However, there's also some value in asserting that these are
      #    passed through without digging into Rails internals. However,
      #    further 'purity' improvements could be made by introspecting on
      #    AR's actual data structures.
      #
      #    That's about three shades on the side of overkill, though.
      #
      def preloader_should_receive(hsh)
        preload_method = Object.new
        mock(preload_method).call(anything, anything) do |models, args|
          expect(args).to eq(hsh)
        end

        stub(Brainstem::Preloader).preload(anything, anything, anything) do |*args|
          args << preload_method
          Brainstem::Preloader.new(*args).call
        end
      end


      it "preloads associations when they are full model-level associations" do
        preloader_should_receive("tasks" => [], "user" => [])
        presenter.group_present(Workspace.order('id desc'), %w[tasks user lead_user tasks_with_lambda])
      end

      it "includes any associations declared via the preload DSL directive" do
        preloader_should_receive("tasks" => [], "posts" => [])
        presenter_class.preload :posts

        presenter.group_present(Workspace.order('id desc'), %w[tasks lead_user tasks_with_lambda])
      end

      it "includes any string associations declared via the preload DSL directive" do
        preloader_should_receive("tasks" => [], "user" => [])
        presenter_class.preload 'user'

        presenter.group_present(Workspace.order('id desc'), %w[tasks user lead_user tasks_with_lambda])
      end

      it "includes any nested hash associations declared via the preload DSL directive" do
        preloader_should_receive("tasks" => [], "user" => [:workspaces], "posts" => ["subject", "user"])
        presenter_class.preload :tasks, "user", "unknown", { "posts" => "subject", "foo" => "bar" },{ :user => :workspaces, "posts" => "user" }

        presenter.group_present(Workspace.order('id desc'), %w[tasks user lead_user tasks_with_lambda])
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
      expect(presenter.extract_filters({ 'owned_by' => [2] })).to eq({ 'owned_by' => [2] })
      expect(presenter.extract_filters({ 'owned_by' => { :ids => [2], 2 => [1] }})).to eq({ 'owned_by' => { :ids => [2], 2 => [1] }})
    end

    it "converts 'true' and 'false' into true and false" do
      presenter_class.filter :owned_by
      expect(presenter.extract_filters({ 'owned_by' => 'true' })).to eq({ 'owned_by' => true })
      expect(presenter.extract_filters({ 'owned_by' => 'TRUE' })).to eq({ 'owned_by' => true })
      expect(presenter.extract_filters({ 'owned_by' => 'false' })).to eq({ 'owned_by' => false })
      expect(presenter.extract_filters({ 'owned_by' => 'FALSE' })).to eq({ 'owned_by' => false })
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

  describe '#apply_ordering_to_scope' do
    let(:presenter_class) { WorkspacePresenter }
    let(:presenter) { presenter_class.new }
    let(:scope) { Workspace.where(nil) }

    it 'uses #calculate_sort_name_and_direction to extract a sort name and direction from user params' do
      presenter_class.sort_order :title, 'workspaces.title'
      mock(presenter).calculate_sort_name_and_direction('order' => 'title:desc') { ['title', 'desc'] }
      presenter.apply_ordering_to_scope(scope, 'order' => 'title:desc')
    end

    context 'when the sort is a proc' do
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

      it 'can chain multiple sorts together' do
        presenter_class.sort_order(:title) do |scope|
          scope.order('workspaces.title desc').order('workspaces.id desc')
        end

        sql = presenter.apply_ordering_to_scope(scope, 'order' => 'title').to_sql
        expect(sql).to match(/order by workspaces.title desc, workspaces.id desc/i)
      end

      it 'chains the primary key onto the end' do
        presenter_class.sort_order(:title) do |scope|
          scope.order('workspaces.title desc')
        end

        sql = presenter.apply_ordering_to_scope(scope, 'order' => 'title').to_sql
        expect(sql).to match(/order by workspaces.title desc, workspaces.id desc/i)
      end
    end

    context 'when the sort is not a proc' do
      it 'applies the named ordering in the given direction' do
        presenter_class.sort_order :title, 'workspaces.title'
        expect(presenter.apply_ordering_to_scope(scope, 'order' => 'title:asc').to_sql).to match(/order by workspaces.title asc/i)
      end

      describe 'deterministic ordering' do
        let(:order) { { 'order' => 'title:asc' } }

        before do
          presenter_class.sort_order :title, 'workspaces.title'
          presenter_class.sort_order :id, 'workspaces.id'
        end

        it 'adds the primary key as a fallback sort' do
          sql = presenter.apply_ordering_to_scope(scope, order).to_sql
          expect(sql).to match(/order by workspaces.title asc, workspaces.id desc/i)
        end
      end
    end

    context 'when the sort is nil' do
      it 'orders by the primary key' do
        sql = presenter.apply_ordering_to_scope(scope, '').to_sql
        expect(sql).to match(/order by workspaces.id desc/i)
      end
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
