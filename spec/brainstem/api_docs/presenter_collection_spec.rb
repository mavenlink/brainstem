require 'spec_helper'
require 'brainstem/api_docs/presenter_collection'

module Brainstem
  module ApiDocs
    describe PresenterCollection do
      let(:presenter)    { Object.new }
      let(:target_class) { Class.new }
      let(:atlas)        { Object.new }
      let(:options)      { {} }

      subject { described_class.new(atlas, options) }

      describe "#find_by_target_class" do
        before do
          stub(presenter) do |p|
            p.target_class { target_class }
          end

          subject << presenter
        end

        context "when matches presenter" do
          it "returns the matching presenter" do
            expect(subject.find_by_target_class(target_class)).to eq presenter
          end
        end

        context "when does not match presenter" do
          it "returns nil" do
            expect(subject.find_by_target_class(Class.new)).to eq nil
          end
        end
      end


      describe "#create_from_target_class" do
        let(:pclm) { Object.new }
        let(:options) { { presenter_constant_lookup_method: pclm } }

        context "when can find constant" do
          before do
            stub(target_class).to_s { "TargetClass" }
            stub(pclm).call("TargetClass") { Object }
          end

          it "creates a new presenter, adding it to the members" do
            presenter = subject.create_from_target_class(target_class)
            expect(subject.first).to eq presenter
            expect(presenter.const).to eq Object
            expect(presenter.target_class).to eq target_class
          end

        end

        context "when cannot find constant" do
          before do
            stub(target_class).to_s { "TargetClass" }
            stub(pclm).call("TargetClass") { raise KeyError }
          end

          it "returns nil and does not append to the members" do
            presenter = subject.create_from_target_class(target_class)
            expect(presenter).to be_nil
          end
        end
      end


      describe "#create_from_presenter_collection" do
        let(:const) { Class.new }

        it "creates a new presenter, adding it to the members" do
          presenter = subject.create_from_presenter_collection(target_class, const)
          expect(subject.first).to eq presenter
          expect(presenter.const).to eq const
          expect(presenter.target_class).to eq target_class
        end
      end

      it_behaves_like "atlas taker"
    end
  end
end
