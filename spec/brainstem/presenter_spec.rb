require 'spec_helper'

describe Brainstem::Presenter do
  describe "class methods" do

    describe "presents method" do
      before do
        @klass = Class.new(Brainstem::Presenter)
      end

      it "records itself as the presenter for the named class as a string" do
        @klass.presents "String"
        Brainstem.presenter_collection.for(String).should be_a(@klass)
      end

      it "records itself as the presenter for the given class" do
        @klass.presents String
        Brainstem.presenter_collection.for(String).should be_a(@klass)
      end

      it "records itself as the presenter for the named classes" do
        @klass.presents String, Array
        Brainstem.presenter_collection.for(String).should be_a(@klass)
        Brainstem.presenter_collection.for(Array).should be_a(@klass)
      end
    end

    describe "implicit namespacing" do
      module V1
        class SomePresenter < Brainstem::Presenter
        end
      end

      it "uses the closest module name as the presenter namespace" do
        V1::SomePresenter.presents String
        Brainstem.presenter_collection(:v1).for(String).should be_a(V1::SomePresenter)
      end

      it "does not map namespaced presenters into the default namespace" do
        V1::SomePresenter.presents String
        Brainstem.presenter_collection.for(String).should be_nil
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
        lambda { @klass.new.call_helper }.should raise_error
        @klass.helper @helper
        @klass.new.call_helper.should == "I work"
        @klass.foo.should == "I work"
      end
    end

    describe "filter method" do
      before do
        @klass = Class.new(Brainstem::Presenter)
      end

      it "creates an entry in the filters class ivar" do
        @klass.filter(:foo, :default => true) { 1 }
        @klass.filters[:foo][0].should eq({"default" => true})
        @klass.filters[:foo][1].should be_a(Proc)
      end

      it "accepts names without blocks" do
        @klass.filter(:foo)
        @klass.filters[:foo][1].should be_nil
      end
    end

    describe "search method" do
      before do
        @klass = Class.new(Brainstem::Presenter)
      end

      it "creates an entry in the search class ivar" do
        @klass.search do end
        @klass.search_block.should be_a(Proc)
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
        data[:id].should eq(@post.id.to_s)
        data[:body].should eq(@post.body)
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

        struct = TimePresenter.new.present_and_post_process("something")
        struct[:time].should =~ iso8601_time
        struct[:date].should =~ iso8601_date
        struct[:recursion][:time].should =~ iso8601_time
        struct[:recursion][:something].first.should =~ iso8601_time
        struct[:recursion][:something].last.should == :else
        struct[:recursion][:foo].should == :bar
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
              :another_subject => association(:subject)
            }
          end
        end

        @presenter = some_presenter.new
        @post = Post.first
      end

      it "outputs the associated object's id and type" do
        data = @presenter.present_and_post_process(@post)
        data[:subject_id].should eq(@post.subject_id.to_s)
        data[:subject_type].should eq(@post.subject_type)
      end

      it "outputs custom names for an associated object's id and type" do
        data = @presenter.present_and_post_process(@post)
        data[:another_subject_id].should eq(@post.subject_id.to_s)
        data[:another_subject_type].should eq(@post.subject_type)
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
        json.keys.should =~ [:id, :updated_at, :something_id, :user_id]
      end

      it "should convert requested has_many associations (includes) into the <association>_ids format" do
        @workspace.tasks.length.should > 0
        @presenter.present_and_post_process(@workspace, ["tasks"])[:task_ids].should =~ @workspace.tasks.map(&:id).map(&:to_s)
      end

      it "should convert requested belongs_to and has_one associations into the <association>_id format when requested" do
        @presenter.present_and_post_process(@workspace, ["user"])[:user_id].should == @workspace.user.id.to_s
      end

      it "converts non-association models into <model>_id format when they are requested" do
        @presenter.present_and_post_process(@workspace, ["lead_user"])[:lead_user_id].should == @workspace.lead_user.id.to_s
      end

      it "handles associations provided with lambdas" do
        @presenter.present_and_post_process(@workspace, ["lead_user_with_lambda"])[:lead_user_with_lambda_id].should == @workspace.lead_user.id.to_s
        @presenter.present_and_post_process(@workspace, ["tasks_with_lambda"])[:tasks_with_lambda_ids].should == @workspace.tasks.map(&:id).map(&:to_s)
      end

      it "should return <association>_id fields when the given association ids exist on the model whether it is requested or not" do
        @presenter.present_and_post_process(@workspace, ["user"])[:user_id].should == @workspace.user_id.to_s

        json = @presenter.present_and_post_process(@workspace, [])
        json.keys.should =~ [:user_id, :something_id, :id, :updated_at]
        json[:user_id].should == @workspace.user_id.to_s
        json[:something_id].should == @workspace.user_id.to_s
      end

      it "should return null, not empty string when ids are missing" do
        @workspace.user = nil
        @workspace.tasks = []
        @presenter.present_and_post_process(@workspace, ["lead_user_with_lambda"])[:lead_user_with_lambda_id].should == nil
        @presenter.present_and_post_process(@workspace, ["user"])[:user_id].should == nil
        @presenter.present_and_post_process(@workspace, ["something"])[:something_id].should == nil
        @presenter.present_and_post_process(@workspace, ["tasks"])[:task_ids].should == []
      end

      context "when the model has an <association>_id method but no column" do
        it "does not include the <association>_id field" do
          def @workspace.synthetic_id
            raise "this explodes because it's not an association"
          end
          @presenter.present_and_post_process(@workspace, []).should_not have_key(:synthetic_id)
        end
      end
    end
  end
end
