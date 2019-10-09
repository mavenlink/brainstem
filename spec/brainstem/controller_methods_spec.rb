require 'spec_helper'
require 'action_controller'

describe Brainstem::ControllerMethods do
  class TasksController
    include Brainstem::ControllerMethods

    attr_accessor :call_results

    def params
      @params ||= ActionController::Parameters.new({ :a => :b })
    end
  end

  before(:all) do
    ActionController::Parameters.action_on_unpermitted_parameters = :raise
  end

  describe "#present_object" do
    before do
      @controller = TasksController.new
    end

    describe '#integration' do
      it 'permits the parameters' do
        # This would throw an UnpermittedParameters exception if we didn't permit the parameters
        @controller.brainstem_present_object([Workspace.find(1), Workspace.find(3)])
        @controller.brainstem_present(Workspace) { Workspace.unscoped }
      end
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
        expect(@controller.call_results[:block_result].pluck(:id)).to eq([1, 3])
      end

      it "works with a Relation" do
        @controller.brainstem_present_object(Workspace.owned_by(1))
        expect(@controller.call_results[:klass]).to eq(Workspace)
        expect(@controller.call_results[:block_result].pluck(:id)).to eq([1, 2, 3, 4])
      end

      it "works with singleton objects" do
        @controller.brainstem_present_object(Workspace.find(1))
        expect(@controller.call_results[:klass]).to eq(Workspace)
        expect(@controller.call_results[:block_result].pluck(:id)).to eq([1])
      end

      it "raises an error when given a key_map" do
        expect {
          @controller.brainstem_present_object(Workspace.find(1), :key_map => { "Workspace" => "your_workspaces" })
        }.to raise_error(/brainstem_key annotation/)
      end

      it "passes through the controller params" do
        @controller.brainstem_present_object(Workspace.find(1))
        expect(@controller.call_results[:options][:params].with_indifferent_access).to eq(@controller.params.merge('only' => '1').to_unsafe_h)
      end

      it "passes through supplied options" do
        @controller.brainstem_present_object(Workspace.find(1), :foo => :bar)
        expect(@controller.call_results[:options][:foo]).to eq(:bar)
      end

      it "adds an only param if there is only one object to present" do
        @controller.brainstem_present_object(Workspace.find(1))
        expect(@controller.call_results[:options][:params][:only]).to eq("1")
      end

      it "doesn't set only if there is more than one object" do
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
