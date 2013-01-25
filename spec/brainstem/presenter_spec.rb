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
        @klass.filters[:foo][0].should eq({:default => true})
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
    describe "converting dates and times" do
      it "should convert all Time-like objects to epochs, but not date objects, which should be iso8601" do
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

        struct = TimePresenter.new.present_and_post_process("something")
        struct[:time].should be_a(Integer)
        struct[:date].should =~ /\d{4}-\d{2}-\d{2}/
        struct[:recursion][:time].should be_a(Integer)
        struct[:recursion][:something].first.should be_a(Integer)
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
        data[:subject_id].should eq(@post.subject_id)
        data[:subject_type].should eq(@post.subject_type)
      end

      it "outputs custom names for an associated object's id and type" do
        data = @presenter.present_and_post_process(@post)
        data[:another_subject_id].should eq(@post.subject_id)
        data[:another_subject_type].should eq(@post.subject_type)
      end
    end
    
    describe "outputting associations" do
      before do
        some_presenter = Class.new(Brainstem::Presenter) do
          presents Workspace

          def present(model)
            {
                :tasks                      => association(:tasks),
                :user                       => association(:user),
                :something                  => association(:user),
                :lead_user                  => association(:lead_user),
                :lead_user_with_lambda      => association { model.user },
                :synthetic                  => association(:synthetic)
            }
          end
        end

        @presenter = some_presenter.new
        @workspace = Workspace.find_by_title "bob workspace 1"
      end

      it "should not convert or return non-included associations, even when they're in the field list, but should return <association>_ids" do
        json = @presenter.present_and_post_process(@workspace, [:user, :user_id, :tasks, :task_ids], [])
        json.should_not have_key(:task_ids)
        json.should_not have_key(:tasks)
        json.should_not have_key(:user)
        json.should have_key(:user_id)
      end

      it "should convert requested has_many associations (includes) into the <association>_ids format, whether or not the field is requested" do
        @workspace.tasks.length.should > 0
        @presenter.present_and_post_process(@workspace, [], [:tasks])[:task_ids].should =~ @workspace.tasks.map(&:id)
        @presenter.present_and_post_process(@workspace, [:tasks, :task_ids], [:tasks])[:task_ids].should =~ @workspace.tasks.map(&:id)
      end

      it "should convert requested belongs_to and has_one associations into the <association>_id format when requested" do
        @presenter.present_and_post_process(@workspace, [], [:user])[:user_id].should == @workspace.user.id
      end

      it "converts non-association models into <model>_id format when they are requested" do
        @presenter.present_and_post_process(@workspace, [], [:lead_user])[:lead_user_id].should == @workspace.lead_user.id
      end

      it "handles associations provided with lambdas" do
        @presenter.present_and_post_process(@workspace, [], [:lead_user_with_lambda])[:lead_user_with_lambda_id].should == @workspace.lead_user.id
      end

      it "should return <association>_id fields when the given association ids exist on the model whether it is requested or not" do
        @presenter.present_and_post_process(@workspace, [], [:user])[:user_id].should == @workspace.user_id

        json = @presenter.present_and_post_process(@workspace, [], [])
        json.keys.should eq([:user_id, :something_id])
        json[:user_id].should == @workspace.user_id
        json[:something_id].should == @workspace.user_id
      end

      context "when the model has an <association>_id method but no column" do
        it "does not include the <association>_id field" do
          def @workspace.synthetic_id
            raise "this explodes because it's not an association"
          end
          @presenter.present_and_post_process(@workspace, [], []).should_not have_key(:synthetic_id)
        end
      end
    end

    describe "selecting fields" do
      before do
        some_presenter = Class.new(Brainstem::Presenter) do
          presents Workspace

          def present(model)
            {
                :id           => model.id,
                :user         => association(:user),
                :tasks        => association(:tasks),
                :updated_at   => model.updated_at,
                :title        => optional_field { model.title },
                :description  => optional_field(:description)
            }
          end
        end
        @presenter = some_presenter.new
        @workspace = Workspace.find_by_title "bob workspace 1"
      end

      it "always returns normal fields" do
        @presenter.present_and_post_process(@workspace, [], []).keys.should =~ [:id, :user_id, :updated_at]
      end

      it "only returns optional_fields when they are explicitly requested" do
        @presenter.present_and_post_process(@workspace, [:title], [])[:title].should eq(@workspace.title)
        @presenter.present_and_post_process(@workspace, [:title, :description], []).keys.should =~ [:id, :user_id, :updated_at, :title, :description]
      end
    end
  end
end
