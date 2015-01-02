require 'spec_helper'

describe Brainstem::Presenter do
  describe "class methods" do

    describe "presents method" do
      before do
        @klass = Class.new(Brainstem::Presenter)
      end

      it "records itself as the presenter for the named class as a string" do
        @klass.presents "String"
        expect(Brainstem.presenter_collection.for(String)).to be_a(@klass)
      end

      it "records itself as the presenter for the given class" do
        @klass.presents String
        expect(Brainstem.presenter_collection.for(String)).to be_a(@klass)
      end

      it "records itself as the presenter for the named classes" do
        @klass.presents String, Array
        expect(Brainstem.presenter_collection.for(String)).to be_a(@klass)
        expect(Brainstem.presenter_collection.for(Array)).to be_a(@klass)
      end
    end

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

    describe "helper method" do
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

    describe "filter method" do
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

    describe "search method" do
      before do
        @klass = Class.new(Brainstem::Presenter)
      end

      it "creates an entry in the search class ivar" do
        @klass.search do end
        expect(@klass.search_block).to be_a(Proc)
      end
    end
  end

  describe "post_process hooks" do
    describe "adding object ids as strings" do
      before do
        post_presenter = Class.new(Brainstem::Presenter) do
          presents Post

          def present(model)
            {
              :body => model.body,
            }
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
        class TimePresenter < Brainstem::Presenter
          def present(model)
            {
              :time => Time.now,
              :date => Date.new,
              :recursion => {
                  :time => Time.now,
                  :something => [Time.now, :else],
                  :foo => :bar
              }
            }
          end
        end

        iso8601_time = /\d{4}-\d{2}-\d{2}T\d{2}\:\d{2}\:\d{2}[-+]\d{2}:\d{2}/
        iso8601_date = /\d{4}-\d{2}-\d{2}/

        struct = TimePresenter.new.present_and_post_process(Workspace.first)
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

          def present(model)
            {
              :body => model.body,
              :subject => association(:subject),
              :another_subject => association(:subject),
              :something_else => association(:subject, :ignore_type => true)
            }
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

        it "skips the polymorphic handling when ignore_type is true" do
          expect(presented_data[:something_else_id]).to eq(post.subject.id.to_s)
          expect(presented_data).not_to have_key(:something_else_type)
          expect(presented_data).not_to have_key(:something_else_ref)
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

          def present(model)
            {
                :updated_at                 => model.updated_at,
                :tasks                      => association(:tasks),
                :user                       => association(:user),
                :something                  => association(:user),
                :lead_user                  => association(:lead_user),
                :lead_user_with_lambda      => association(:json_name => "users") { |model| model.user },
                :tasks_with_lambda          => association(:json_name => "tasks") { |model| Task.where(:workspace_id => model) },
                :synthetic                  => association(:synthetic)
            }
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
        expect(@presenter.present_and_post_process(@workspace, ["tasks"])[:task_ids]).to match_array(@workspace.tasks.map(&:id).map(&:to_s))
      end

      it "should convert requested belongs_to and has_one associations into the <association>_id format when requested" do
        expect(@presenter.present_and_post_process(@workspace, ["user"])[:user_id]).to eq(@workspace.user.id.to_s)
      end

      it "converts non-association models into <model>_id format when they are requested" do
        expect(@presenter.present_and_post_process(@workspace, ["lead_user"])[:lead_user_id]).to eq(@workspace.lead_user.id.to_s)
      end

      it "handles associations provided with lambdas" do
        expect(@presenter.present_and_post_process(@workspace, ["lead_user_with_lambda"])[:lead_user_with_lambda_id]).to eq(@workspace.lead_user.id.to_s)
        expect(@presenter.present_and_post_process(@workspace, ["tasks_with_lambda"])[:tasks_with_lambda_ids]).to eq(@workspace.tasks.map(&:id).map(&:to_s))
      end

      it "should return <association>_id fields when the given association ids exist on the model whether it is requested or not" do
        expect(@presenter.present_and_post_process(@workspace, ["user"])[:user_id]).to eq(@workspace.user_id.to_s)

        json = @presenter.present_and_post_process(@workspace, [])
        expect(json.keys).to match_array([:user_id, :something_id, :id, :updated_at])
        expect(json[:user_id]).to eq(@workspace.user_id.to_s)
        expect(json[:something_id]).to eq(@workspace.user_id.to_s)
      end

      it "should return null, not empty string when ids are missing" do
        @workspace.user = nil
        @workspace.tasks = []
        expect(@presenter.present_and_post_process(@workspace, ["lead_user_with_lambda"])[:lead_user_with_lambda_id]).to eq(nil)
        expect(@presenter.present_and_post_process(@workspace, ["user"])[:user_id]).to eq(nil)
        expect(@presenter.present_and_post_process(@workspace, ["something"])[:something_id]).to eq(nil)
        expect(@presenter.present_and_post_process(@workspace, ["tasks"])[:task_ids]).to eq([])
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
end
