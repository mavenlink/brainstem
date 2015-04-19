require 'spec_helper'
require 'brainstem/concerns/controller_param_management'

describe Brainstem::Concerns::ControllerParamManagement do
  class TasksController
    include Brainstem::Concerns::ControllerParamManagement

    def controller_name
      'tasks'
    end
  end

  before do
    TasksController.brainstem_model_name = nil
    TasksController.brainstem_plural_model_name = nil
  end

  describe '.brainstem_model_name' do
    it 'is settable on the controller' do
      TasksController.brainstem_model_name = 'thingy'
      expect(TasksController.new.brainstem_model_name).to eq 'thingy'
    end

    it 'has good defaults' do
      expect(TasksController.new.brainstem_model_name).to eq 'task'
      expect(TasksController.new.brainstem_plural_model_name).to eq 'tasks'
    end
  end

  describe '.brainstem_plural_model_name' do
    it 'is infered from the singular model name' do
      TasksController.brainstem_model_name = 'thingy'
      expect(TasksController.new.brainstem_plural_model_name).to eq 'thingies'
    end

    it 'can be overridden' do
      TasksController.brainstem_model_name = 'thingy'
      TasksController.brainstem_plural_model_name = 'thingzees'
      expect(TasksController.new.brainstem_plural_model_name).to eq 'thingzees'
    end
  end
end