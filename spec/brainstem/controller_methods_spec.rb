require 'spec_helper'

describe Brainstem::ControllerMethods do
  class TasksController
    include Brainstem::ControllerMethods

    attr_accessor :call_results

    def params
      { :a => :b }
    end
  end

  describe "#present_object" do
    before do
      @controller = TasksController.new
    end

    describe "calling #present with sensible params" do
      before do
        def @controller.brainstem_present(klass, options)
          @call_results = { :klass => klass, :options => options, :block_result => yield }
        end
      end

      it "works with arrays of ActiveRecord objects" do
        @controller.brainstem_present_object([Workspace.find(1), Workspace.find(3)])
        expect(@controller.call_results[:klass]).to eq(Workspace)
        expect(@controller.call_results[:options][:brainstem_key]).to eq("workspaces")
        expect(@controller.call_results[:block_result].pluck(:id)).to eq([1, 3])
      end

      it "works with a Relation" do
        @controller.brainstem_present_object(Workspace.owned_by(1))
        expect(@controller.call_results[:klass]).to eq(Workspace)
        expect(@controller.call_results[:options][:brainstem_key]).to eq("workspaces")
        expect(@controller.call_results[:block_result].pluck(:id)).to eq([1, 2, 3, 4])
      end

      it "works with singleton objects" do
        @controller.brainstem_present_object(Workspace.find(1))
        expect(@controller.call_results[:klass]).to eq(Workspace)
        expect(@controller.call_results[:options][:brainstem_key]).to eq("workspaces")
        expect(@controller.call_results[:block_result].pluck(:id)).to eq([1])
      end

      it "accepts a key map" do
        @controller.brainstem_present_object(Workspace.find(1), :key_map => { "Workspace" => "your_workspaces" })
        expect(@controller.call_results[:klass]).to eq(Workspace)
        expect(@controller.call_results[:options][:brainstem_key]).to eq("your_workspaces")
        expect(@controller.call_results[:block_result].pluck(:id)).to eq([1])
      end

      it "passes through the controller params" do
        @controller.brainstem_present_object(Workspace.find(1), :key_map => { "Workspace" => "your_workspaces" })
        expect(@controller.call_results[:options][:params]).to eq(@controller.params.merge(:only => '1'))
      end

      it "passes through supplied options" do
        @controller.brainstem_present_object(Workspace.find(1), :foo => :bar)
        expect(@controller.call_results[:options][:foo]).to eq(:bar)
      end

      it "adds an only param if there is only one object to present" do
        @controller.brainstem_present_object(Workspace.find(1))
        expect(@controller.call_results[:options][:params][:only]).to eq("1")

        @controller.brainstem_present_object(Workspace.all)
        expect(@controller.call_results[:options][:params][:only]).to be_nil
      end

      it "passes :apply_default_filters => false to the PresenterCollection so that filters are not applied by default" do
        @controller.brainstem_present_object(Workspace.find(1))
        expect(@controller.call_results[:options][:apply_default_filters]).to eq(false)
      end
    end
  end
end
