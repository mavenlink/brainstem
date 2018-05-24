require 'spec_helper'
require 'brainstem/api_docs/introspectors/abstract_introspector'

module Brainstem
  module ApiDocs
    module Introspectors
      describe AbstractIntrospector do
        subject { AbstractIntrospector.send(:new) }

        describe ".with_loaded_environment" do
          it "passes along all options" do
            any_instance_of(AbstractIntrospector) { |instance| stub(instance).one=(1) }
            mock.proxy(AbstractIntrospector).new(one: 1) do |obj|
              stub(obj) do |stub|
                stub.load_environment!
              end
            end

            AbstractIntrospector.with_loaded_environment(one: 1)
          end

          it "invokes #load_environment! on the instance" do
            stub.proxy(AbstractIntrospector).new do |obj|
              mock(obj).load_environment!
            end

            AbstractIntrospector.with_loaded_environment
          end

          it "returns the instance" do
            instance = Object.new
            stub(instance).load_environment!
            stub.proxy(AbstractIntrospector).new { |_| instance }

            expect(AbstractIntrospector.with_loaded_environment).to eq instance
          end
        end

        describe "#initialize" do
          it "is private" do
            expect { AbstractIntrospector.new }.to raise_error NoMethodError
            expect { AbstractIntrospector.send(:new) }.not_to raise_error
          end
        end

        describe "#load_environment!" do
          it "is not implemented" do
            expect { subject.send(:load_environment!) }.to raise_error NotImplementedError
          end

        end

        describe "#controllers" do
          it "is not implemented" do
            expect { subject.controllers }.to raise_error NotImplementedError
          end
        end

        describe "#presenters" do
          it "is not implemented" do
            expect { subject.presenters }.to raise_error NotImplementedError
          end
        end

        describe "#routes" do
          it "is not implemented" do
            expect { subject.routes }.to raise_error NotImplementedError
          end
        end

        describe "#valid?" do
          let! (:controllers_valid) { true }
          let! (:presenters_valid)  { true }
          let! (:routes_valid)      { true }

          before do
            stub(subject) do |s|
              s.valid_controllers?  { controllers_valid }
              s.valid_presenters?   { presenters_valid }
              s.valid_routes?       { routes_valid }
            end
          end

          context "when controllers, presenters, and routes are valid" do
            it "is valid" do
              expect(subject.valid?).to eq true
            end
          end

          context "when controllers are invalid" do
            let(:controllers_valid) { false }

            it "is not valid" do
              expect(subject.valid?).to eq false
            end

          end

          context "when presenters are invalid" do
            let(:presenters_valid) { false }

            it "is not valid" do
              expect(subject.valid?).to eq false
            end
          end

          context "when routes are invalid" do
            let(:routes_valid) { false }

            it "is not valid" do
              expect(subject.valid?).to eq false
            end
          end
        end

        describe "#valid_controllers?" do
          it "is valid when a collection of at least one class" do
            stub(subject).controllers { [ Integer ] }
            expect(subject.send(:valid_controllers?)).to eq true
          end

          it "is invalid when not a collection" do
            stub(subject).controllers { { dog: "woof" } }
            expect(subject.send(:valid_controllers?)).to eq false
          end

          it "is invalid when empty" do
            stub(subject).controllers { [] }
            expect(subject.send(:valid_controllers?)).to eq false
          end
        end

        describe "#valid_presenters?" do
          it "is valid when a collection of zero or more classes" do
            stub(subject).presenters { [ Integer ] }
            expect(subject.send(:valid_presenters?)).to eq true
          end

          it "is valid when empty" do
            stub(subject).presenters { [] }
            expect(subject.send(:valid_presenters?)).to eq true
          end

          it "is invalid when not a collection" do
            stub(subject).presenters { { dog: "woof" } }
            expect(subject.send(:valid_presenters?)).to eq false
          end

        end

        describe "#valid_routes?" do
          it "is valid when a collection of hashes with specific keys" do
            stub(subject).routes { [
              {
                path: "blah",
                controller: "blah",
                action: "blah",
                http_methods: ['blah']
              }
            ] }

            expect(subject.send(:valid_routes?)).to eq true
          end

          it "is invalid when not a collection" do
            stub(subject).routes { {} }
            expect(subject.send(:valid_routes?)).to eq false
          end

          it "is invalid when empty" do
            stub(subject).routes { [] }
            expect(subject.send(:valid_routes?)).to eq false
          end

          it "is invalid if any one hash is missing a required key" do
            stub(subject).routes { [
              {
                path: "blah",
                controller: "blah",
                action: "blah"
              }
            ] }

            expect(subject.send(:valid_routes?)).to eq false
          end
        end
      end
    end
  end
end
