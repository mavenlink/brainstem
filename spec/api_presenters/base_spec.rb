require 'spec_helper'

describe ApiPresenters::Base do
  describe "post_process hooks" do
    describe "converting dates and times" do
      it "should convert all Time-like objects to epochs, but not date objects, which should be iso8601" do
        some_presenter = Class.new(ApiPresenters::Base) do
          def present(model)
            {
              :time => Time.now,
              :date => Date.today,
              :recursion => {
                  :time => Time.now,
                  :something => [Time.now, :else],
                  :foo => :bar
              },
              :time_with_zone => Workspace.last.created_at
            }
          end
        end

        struct = some_presenter.new.present_and_post_process("something")
        struct[:time].should be_a(Integer)
        struct[:date].should =~ /\d{4}-\d{2}-\d{2}/
        struct[:recursion][:time].should be_a(Integer)
        struct[:recursion][:something].first.should be_a(Integer)
        struct[:recursion][:something].last.should == :else
        struct[:recursion][:foo].should == :bar
        struct[:time_with_zone].should be_a(Integer)
      end
    end

    describe "outputting associations" do
      before do
        some_presenter = Class.new(ApiPresenters::Base) do
          def present(model)
            {
                :stories                    => association(:stories),
                :creator                    => association(:creator),
                :something                  => association(:creator),
                :primary_maven              => association(:primary_maven),
                :primary_maven_with_lambda  => association { model.primary_maven },
                :synthetic                  => association(:synthetic)
            }
          end
        end
        @presenter = some_presenter.new
      end

      it "should not convert or return non-included associations, even when they're in the field list" do
        json = @presenter.present_and_post_process(workspaces(:jane_car_wash), [:creator, :creator_id, :stories, :story_ids], [])
        json.should_not have_key(:story_ids)
        json.should_not have_key(:stories)
        json.should_not have_key(:creator)
        json.should have_key(:creator_id)
      end

      it "should convert requested has_many associations (includes) into the <association>_ids format, whether or not the field is requested" do
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [], [:stories])[:story_ids].should =~ workspaces(:jane_car_wash).stories.map(&:id)
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [:stories, :story_ids], [:stories])[:story_ids].should =~ workspaces(:jane_car_wash).stories.map(&:id)
      end

      it "should convert requested belongs_to and has_one associations into the <association>_id format when requested" do
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [], [:primary_maven])[:primary_maven_id].should == workspaces(:jane_car_wash).primary_maven.id
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [:primary_maven_id, :primary_maven], [:primary_maven])[:primary_maven_id].should == workspaces(:jane_car_wash).primary_maven.id
      end

      it "should return <association>_id fields when the given association ids exist on the model whether it is requested or not" do
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [], [:creator])[:creator_id].should == workspaces(:jane_car_wash).creator_id

        json = @presenter.present_and_post_process(workspaces(:jane_car_wash), [], [])
        json.keys.should =~ [:creator_id, :something_id]
        json[:creator_id].should == workspaces(:jane_car_wash).creator_id
      end

      it "should leave non-active-records alone" do
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [], [:creator])[:creator_id].should == workspaces(:jane_car_wash).creator_id
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [:creator, :creator_id], [:creator])[:creator_id].should == workspaces(:jane_car_wash).creator_id
      end

      context "when the model has an <association>_id method but no column" do
        it "does not include the <association>_id field" do
          workspace = workspaces(:jane_car_wash)
          def workspace.synthetic_id; raise "Why you call me?"; end
          @presenter.present_and_post_process(workspace, [], []).should_not have_key(:synthetic_id)
        end
      end
    end

    describe "selecting fields" do
      before do
        some_presenter = Class.new(ApiPresenters::Base) do
          def present(model)
            {
                :id           => model.id,
                :creator_id   => model.creator_id,
                :title        => optional_field { model.title },
                :description  => optional_field { model.description }
            }
          end
        end
        @presenter = some_presenter.new
      end

      it "always returns normal fields" do
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [], []).should == { :id => workspaces(:jane_car_wash).id,
                                                                                            :creator_id => workspaces(:jane_car_wash).creator_id }
      end

      it "only returns optional_fields when they are explicitly requested" do
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [:title], []).should == { :title => workspaces(:jane_car_wash).title,
                                                                                                  :id => workspaces(:jane_car_wash).id,
                                                                                                  :creator_id => workspaces(:jane_car_wash).creator_id }
        @presenter.present_and_post_process(workspaces(:jane_car_wash), [:title, :description], []).should == { :title => workspaces(:jane_car_wash).title,
                                                                                                                :description => workspaces(:jane_car_wash).description,
                                                                                                                :id => workspaces(:jane_car_wash).id,
                                                                                                                :creator_id => workspaces(:jane_car_wash).creator_id }
      end
    end
  end
end