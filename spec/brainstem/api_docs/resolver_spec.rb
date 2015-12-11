require 'spec_helper'
require 'brainstem/api_docs/resolver'

class ActiveRecord::Base
end

module Brainstem
  module ApiDocs
    describe Resolver do
      let(:atlas) { Object.new }
      let(:options) { { } }

      subject { described_class.new(atlas, options) }

      describe "#initialize" do
        it "requires an atlas" do
          expect { described_class.new }.to raise_error ArgumentError
          expect { described_class.new(atlas) }.not_to raise_error
        end
      end

      describe "#find_by_class" do
        let(:klass) { Class.new }
        let(:result) { Object.new }

        context "when activerecord" do
          let(:klass)  { Class.new(ActiveRecord::Base) }

          it "finds the presenter from the target class" do
            mock(subject).find_presenter_from_target_class(klass) { result }
            expect(subject.find_by_class(klass)).to eq result
          end
        end

        context "when symbol" do
          context "when polymorphic" do
            let(:klass) { :polymorphic }

            it "returns nil" do
              expect(subject.find_by_class(klass)).to be_nil
            end
          end
        end

        context "when not found" do
          it "returns nil" do
            expect(subject.find_by_class(klass)).to be_nil
          end
        end
      end


      describe "#find_presenter_from_target_class" do
        let(:klass)             { Class.new }
        let(:presenter_const)   { Class.new }
        let(:pclm)              { Object.new }
        let(:presenter_wrapper) { OpenStruct.new(const: presenter_const) }
        let(:options)           { { presenter_constant_lookup_method: pclm } }

        before do
          stub(klass).to_s { "Klass" }
          mock(pclm).call("Klass") { presenter_const }
          stub(atlas).presenters { [ presenter_wrapper ] }
        end

        it "returns the presenter" do
          expect(subject.send(:find_presenter_from_target_class, klass)).to eq presenter_wrapper
        end
      end
    end
  end
end
