require 'spec_helper'
require 'brainstem/api_docs/presenter_collection'

module Brainstem
  module ApiDocs
    describe PresenterCollection do
      let(:presenter) { Object.new }

      subject { ::Brainstem::ApiDocs::PresenterCollection.new }


      describe "#find_by_presents" do
        before do
          stub(presenter) do |p|
            p.presents { "thing" }
          end

          subject << presenter
        end

        context "when matches presenter" do
          it "returns the matching presenter" do
            expect(subject.find_by_presents("thing")).to eq presenter
          end
        end

        context "when does not match presenter" do
          it "returns nil" do
            expect(subject.find_by_presents("thing 2")).to eq nil
          end
        end
      end


      describe "#create_from_presents" do
        let(:pclm) { Object.new }
        subject { ::Brainstem::ApiDocs::PresenterCollection.new(presenter_constant_lookup_method: pclm) }


        context "when can find constant" do
          before do
            stub(pclm).call("Thing") { Object }
          end

          it "creates a new presenter, adding it to the members" do
            presenter = subject.create_from_presents(:thing)
            expect(subject.first).to eq presenter
            expect(presenter.const).to eq Object
            expect(presenter.presents).to eq :thing
          end

        end

        context "when cannot find constant" do
          before do
            stub(pclm).call("Thing") { raise KeyError }
          end

          it "returns nil and does not append to the members" do
            presenter = subject.create_from_presents(:thing)
            expect(presenter).to be_nil
          end
        end
      end


    end
  end
end
