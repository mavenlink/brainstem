require 'spec_helper'

describe Brainstem::Presenter do
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

  describe "class methods" do

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

    describe ".helper" do
      before do
        @klass = Class.new(Brainstem::Presenter) do
          def call_helper
            foo
          end
        end
        @helper = Module.new do
          def foo
            "I work"
          end
        end
      end

      it "includes and extends the given module" do
        expect { @klass.new.call_helper }.to raise_error
        @klass.helper @helper
        expect(@klass.new.call_helper).to eq("I work")
        expect(@klass.foo).to eq("I work")
      end
    end

    describe ".filter" do
      before do
        @klass = Class.new(Brainstem::Presenter)
      end

      it "creates an entry in the filters class ivar" do
        @klass.filter(:foo, :default => true) { 1 }
        expect(@klass.filters[:foo][0]).to eq({"default" => true})
        expect(@klass.filters[:foo][1]).to be_a(Proc)
      end

      it "accepts names without blocks" do
        @klass.filter(:foo)
        expect(@klass.filters[:foo][1]).to be_nil
      end
    end

    describe ".search" do
      before do
        @klass = Class.new(Brainstem::Presenter)
      end

      it "creates an entry in the search class ivar" do
        @klass.search do end
        expect(@klass.search_block).to be_a(Proc)
      end
    end
  end

  describe "#present_fields" do
    let(:presenter) { WorkspacePresenter.new }
    let(:model) { Workspace.find(1) }

    it 'only includes fields' do
      expect(presenter.present_fields(model).length).to eq presenter.configuration[:fields].length
    end

    it 'calls named methods' do
      expect(presenter.present_fields(model)[:title]).to eq model.title
    end

    it 'can call methods with :via' do
      presenter.configuration[:fields][:title].options[:via] = :description
      expect(presenter.present_fields(model)[:title]).to eq model.description
    end

    it 'can call a dynamic lambda' do
      expect(presenter.present_fields(model)[:dynamic_title]).to eq "title: #{model.title}"
    end

    it 'handles nesting' do
      expect(presenter.present_fields(model)[:permissions][:access_level]).to eq 2
    end
  end

  describe "post_process hooks" do
    describe "adding object ids as strings" do
      before do
        post_presenter = Class.new(Brainstem::Presenter) do
          presents Post

          presenter do
            fields do
              field :body, :string
            end
          end
        end

        @presenter = post_presenter.new
        @post = Post.first
      end

      it "outputs the associated object's id and type" do
        data = @presenter.present_and_post_process(@post)
        expect(data[:id]).to eq(@post.id.to_s)
        expect(data[:body]).to eq(@post.body)
      end
    end

    describe "converting dates and times" do
      it "should convert all Time-and-date-like objects to iso8601" do
        presenter = Class.new(Brainstem::Presenter) do
          presenter do
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
        end

        iso8601_time = /\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}[-+]\d{2}:\d{2}/
        iso8601_date = /\d{4}-\d{2}-\d{2}/

        struct = presenter.new.present_and_post_process(Workspace.first)
        expect(struct[:time]).to match(iso8601_time)
        expect(struct[:date]).to match(iso8601_date)
        expect(struct[:recursion][:time]).to match(iso8601_time)
        expect(struct[:recursion][:something].first).to match(iso8601_time)
        expect(struct[:recursion][:something].last).to eq(:else)
        expect(struct[:recursion][:foo]).to eq(:bar)
      end
    end

    describe "outputting polymorphic associations" do
      before do
        some_presenter = Class.new(Brainstem::Presenter) do
          presents Post

          presenter do
            fields do
              field :body, :string
            end

            associations do
              association :subject, :polymorphic
              association :another_subject, :polymorphic, via: :subject
              association :forced_model, Workspace, via: :subject
            end
          end
        end

        @presenter = some_presenter.new
      end

      let(:presented_data) { @presenter.present_and_post_process(post) }

      context "when polymorphic association exists" do
        let(:post) { Post.find(1) }

        it "outputs the object as a hash with the id & class table name" do
          expect(presented_data[:subject_ref]).to eq({ :id => post.subject.id.to_s,
                                                       :key => post.subject.class.table_name })
        end

        it "outputs custom names for the object as a hash with the id & class table name" do
          expect(presented_data[:another_subject_ref]).to eq({ :id => post.subject.id.to_s,
                                                               :key => post.subject.class.table_name })
        end

        it "skips the polymorphic handling when a model is given" do
          expect(presented_data[:forced_model_id]).to eq(post.subject.id.to_s)
          expect(presented_data).not_to have_key(:forced_model_type)
          expect(presented_data).not_to have_key(:forced_model_ref)
        end
      end

      context "when polymorphic association does not exist" do
        let(:post) { Post.find(3) }

        it "outputs nil" do
          expect(presented_data[:subject_ref]).to be_nil
        end

        it "outputs nil" do
          expect(presented_data[:another_subject_ref]).to be_nil
        end
      end
    end

    describe "outputting associations" do
      before do
        some_presenter = Class.new(Brainstem::Presenter) do
          presents Workspace

          presenter do
            fields do
              field :updated_at, :datetime
            end

            associations do
              association :tasks, Task
              association :user, User
              association :something, User, via: :user
              association :lead_user, User
              association :lead_user_with_lambda, User, dynamic: lambda { |model| model.user }
              association :tasks_with_lambda, Task, dynamic: lambda { |model| Task.where(:workspace_id => model) }
              association :synthetic, :polymorphic
            end
          end
        end

        @presenter = some_presenter.new
        @workspace = Workspace.find_by_title "bob workspace 1"
      end

      it "should not convert or return non-included associations, but should return <association>_id for belongs_to relationships, plus all fields" do
        json = @presenter.present_and_post_process(@workspace, [])
        expect(json.keys).to match_array([:id, :updated_at, :something_id, :user_id])
      end

      it "should convert requested has_many associations (includes) into the <association>_ids format" do
        expect(@workspace.tasks.length).to be > 0
        expect(@presenter.present_and_post_process(@workspace, [:tasks])[:task_ids]).to match_array(@workspace.tasks.map(&:id).map(&:to_s))
      end

      it "should convert requested belongs_to and has_one associations into the <association>_id format when requested" do
        expect(@presenter.present_and_post_process(@workspace, [:user])[:user_id]).to eq(@workspace.user.id.to_s)
      end

      it "converts non-association models into <model>_id format when they are requested" do
        expect(@presenter.present_and_post_process(@workspace, [:lead_user])[:lead_user_id]).to eq(@workspace.lead_user.id.to_s)
      end

      it "handles associations provided with lambdas" do
        expect(@presenter.present_and_post_process(@workspace, [:lead_user_with_lambda])[:lead_user_with_lambda_id]).to eq(@workspace.lead_user.id.to_s)
        expect(@presenter.present_and_post_process(@workspace, [:tasks_with_lambda])[:tasks_with_lambda_ids]).to eq(@workspace.tasks.map(&:id).map(&:to_s))
      end

      it "should return <association>_id fields when the given association ids exist on the model whether it is requested or not" do
        expect(@presenter.present_and_post_process(@workspace, [:user])[:user_id]).to eq(@workspace.user_id.to_s)

        json = @presenter.present_and_post_process(@workspace, [])
        expect(json.keys).to match_array([:user_id, :something_id, :id, :updated_at])
        expect(json[:user_id]).to eq(@workspace.user_id.to_s)
        expect(json[:something_id]).to eq(@workspace.user_id.to_s)
      end

      it "should return null, not empty string when ids are missing" do
        @workspace.user = nil
        @workspace.tasks = []
        expect(@presenter.present_and_post_process(@workspace, [:lead_user_with_lambda])[:lead_user_with_lambda_id]).to eq(nil)
        expect(@presenter.present_and_post_process(@workspace, [:user])[:user_id]).to eq(nil)
        expect(@presenter.present_and_post_process(@workspace, [:something])[:something_id]).to eq(nil)
        expect(@presenter.present_and_post_process(@workspace, [:tasks])[:task_ids]).to eq([])
      end

      context "when the model has an <association>_id method but no column" do
        it "does not include the <association>_id field" do
          def @workspace.synthetic_id
            raise "this explodes because it's not an association"
          end
          expect(@presenter.present_and_post_process(@workspace, [])).not_to have_key(:synthetic_id)
        end
      end
    end
  end

  describe '#allowed_associations' do
    let(:presenter_class) do
      Class.new(Brainstem::Presenter) do
        presenter do
          associations do
            association :user, User
            association :workspace, Workspace
            association :task, Task, restrict_to_only: true
          end
        end
      end
    end

    let(:presenter_instance) { presenter_class.new }

    it 'returns all associations that are not restrict_to_only' do
      expect(presenter_instance.allowed_associations(is_only_query = false).keys).to match_array ['user', 'workspace']
    end

    it 'returns associations that are restrict_to_only if is_only_query is true' do
      expect(presenter_instance.allowed_associations(is_only_query = true).keys).to match_array ['user', 'workspace', 'task']
    end
  end
end
