require 'spec_helper'
require 'spec_helpers/presenters'

describe Brainstem::ControllerMethods do
  class FakeController
    include Brainstem::ControllerMethods

    attr_accessor :call_results

    def params
      { :a => :b }
    end
  end

  before do
    UserPresenter.presents User
    TaskPresenter.presents Task
    WorkspacePresenter.presents Workspace
    PostPresenter.presents Post
  end

  describe "#present_object" do
    before do
      @controller = FakeController.new
    end

    describe "calling #present with sensible params" do
      before do
        def @controller.present(klass, options)
          @call_results = { :klass => klass, :options => options, :block_result => yield }
        end
      end

      it "works with arrays of ActiveRecord objects" do
        @controller.present_object([Workspace.find(1), Workspace.find(3)])
        @controller.call_results[:klass].should == Workspace
        @controller.call_results[:options][:as].should == "workspaces"
        @controller.call_results[:block_result].pluck(:id).should == [1, 3]
      end

      it "works with a Relation" do
        @controller.present_object(Workspace.owned_by(1))
        @controller.call_results[:klass].should == Workspace
        @controller.call_results[:options][:as].should == "workspaces"
        @controller.call_results[:block_result].pluck(:id).should == [1, 2, 3, 4]
      end

      it "works with singleton objects" do
        @controller.present_object(Workspace.find(1))
        @controller.call_results[:klass].should == Workspace
        @controller.call_results[:options][:as].should == "workspaces"
        @controller.call_results[:block_result].pluck(:id).should == [1]
      end

      it "accepts a key map" do
        @controller.present_object(Workspace.find(1), :key_map => { "Workspace" => "your_workspaces" })
        @controller.call_results[:klass].should == Workspace
        @controller.call_results[:options][:as].should == "your_workspaces"
        @controller.call_results[:block_result].pluck(:id).should == [1]
      end

      it "passes through the controller params" do
        @controller.present_object(Workspace.find(1), :key_map => { "Workspace" => "your_workspaces" })
        @controller.call_results[:options][:params].should == @controller.params.merge(:only => '1')
      end

      it "passes through supplied options" do
        @controller.present_object(Workspace.find(1), :foo => :bar)
        @controller.call_results[:options][:foo].should == :bar
      end

      it "adds an only param if there is only one object to present" do
        @controller.present_object(Workspace.find(1))
        @controller.call_results[:options][:params][:only].should == "1"

        @controller.present_object(Workspace.all)
        @controller.call_results[:options][:params][:only].should be_nil
      end
    end
  end
end
