require 'spec_helper'
require 'brainstem/cli'

describe "Command line" do
  let(:dummy_puts) { Object.new }
  let(:options) { { log_method: dummy_puts } }
  let(:args) { [] }

  subject { Brainstem::Cli.new(args, options) }

  describe "#initialize" do
    it "accepts options and sets them" do
      expect(subject.send(:log_method)).to eq dummy_puts
    end

    it "saves the raw args to _args and freezes them" do
      expect(subject._args).to eq []
      expect(subject._args).to be_frozen
    end

  end

  context "when called with no commands" do
    it "produces response text" do
      mock(dummy_puts).call(anything) do |text|
        expect(text).to include "Commonly used commands"
      end

      subject.call
    end
  end

  context "when called with a command" do
    let(:args) { [ 'fake' ] }

    it "sets the requested command" do
      expect(subject.requested_command).to eq 'fake'
    end

    context "when the command exists" do
      let(:fake_command_class) { Proc.new { false } }
      let(:args) { %w(fake --silent) }

      before do
        stub(subject).commands { { 'fake' => fake_command_class } }
      end

      it "calls the command, passing it the args less one" do
        mock(fake_command_class).call(['--silent'])
        subject.call
      end
    end

    context "when the command does not exist" do
      let(:args) { [ 'fake' ] }

      it "produces response text" do
        mock(dummy_puts).call(anything) do |text|
          expect(text).to include "Commonly used commands"
        end

        subject.call
    end

    end
  end
end
