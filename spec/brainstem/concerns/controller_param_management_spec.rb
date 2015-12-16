require 'spec_helper'
require 'brainstem/concerns/controller_param_management'

describe Brainstem::Concerns::ControllerParamManagement do
  subject do
    Class.new do
      include Brainstem::Concerns::ControllerParamManagement

      def controller_name
        self.class.controller_name
      end

      def self.controller_name
        'tasks'
      end
    end
  end

  before do
    subject.brainstem_model_name = nil
    subject.brainstem_plural_model_name = nil
  end

  describe '.brainstem_model_name' do
    it 'is settable on the controller' do
      subject.brainstem_model_name = 'thingy'
      expect(subject.new.brainstem_model_name).to eq 'thingy'
    end

    it 'has good defaults' do
      expect(subject.new.brainstem_model_name).to eq 'task'
      expect(subject.new.brainstem_plural_model_name).to eq 'tasks'
    end

    it "has good defaults on the class level" do
      expect(subject.brainstem_model_name).to eq 'task'
      expect(subject.brainstem_plural_model_name).to eq 'tasks'
    end
  end

  describe '.brainstem_plural_model_name' do
    it 'is infered from the singular model name' do
      subject.brainstem_model_name = 'thingy'
      expect(subject.brainstem_plural_model_name).to eq 'thingies'
      expect(subject.new.brainstem_plural_model_name).to eq 'thingies'
    end

    it 'can be overridden' do
      subject.brainstem_model_name = 'thingy'
      subject.brainstem_plural_model_name = 'thingzees'
      expect(subject.brainstem_plural_model_name).to eq 'thingzees'
      expect(subject.new.brainstem_plural_model_name).to eq 'thingzees'
    end
  end

  describe '.brainstem_model_class' do
    it "classifies and constantizes the brainstem_model_name" do
      subject.brainstem_model_name = "object"
      expect(subject.brainstem_model_class).to eq Object
    end
  end
end
