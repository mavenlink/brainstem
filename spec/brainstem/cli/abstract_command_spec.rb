require 'spec_helper'
require 'brainstem/cli/abstract_command'

module Brainstem
  module CLI
    describe AbstractCommand do
      let(:options) { { } }
      subject { AbstractCommand.new(options) }


      describe ".call" do
        before do
          any_instance_of(AbstractCommand) do |klass|
            stub(klass) do |obj|
              obj.call
              obj.extract_options!
            end
          end
        end

        it "creates a new instance" do
          mock.proxy(AbstractCommand).new([])
          AbstractCommand.call([])
        end

        it "passes its args to the instance" do
          mock.proxy(AbstractCommand).new(%w(--silent))
          AbstractCommand.call(%w(--silent))
        end

        it "calls the new instance" do
          any_instance_of(AbstractCommand) do |klass|
            mock(klass).call
          end

          AbstractCommand.call([])
        end

        it "it returns the new instance" do
          expect(AbstractCommand.call).to be_an AbstractCommand
        end
      end


      describe "#extract_options!" do
        let(:option_parser) { Object.new }
        let(:args) { %w(--silent --pretend) }

        it "feeds the args to the class's option parser" do
          mock(option_parser).order!(args)

          any_instance_of(AbstractCommand) do |klass|
            mock(klass).option_parser { option_parser }
          end

          AbstractCommand.new(args)
        end
      end


      describe "#option_parser" do
        it "is not implemented" do
          expect { AbstractCommand.new }.to raise_error NotImplementedError
        end
      end


      describe "#initialize" do
        it "extracts options from args" do
          any_instance_of(AbstractCommand) do |instance|
            mock(instance).extract_options!
          end

          AbstractCommand.new
        end
      end

      describe "#call" do
        before do
          any_instance_of(AbstractCommand) do |instance|
            stub(instance).extract_options!
          end
        end

        it "is not implemented" do
          expect { subject.call }.to raise_error NotImplementedError
        end
      end
    end
  end
end
