require 'spec_helper'
require 'brainstem/api_docs/controller_collection'

module Brainstem
  module ApiDocs
    describe ControllerCollection do
      let(:controller) { Object.new }
      let(:atlas)      { Object.new }
      let(:options)    { {} }

      subject { described_class.new(atlas, options) }

      describe "#find_by_route" do
        before do
          stub(controller) do |c|
            c.path    { "/posts" }
            c.const   { Object }
            c.action  { "index" }
          end

          subject << controller
        end

        context "when matches route" do
          it "returns the matching controller" do
            route = { controller: Object }
            expect(subject.find_by_route(route)).to eq controller
          end
        end

        context "when does not match route" do
          it "returns nil" do
            route = { controller: TrueClass }
            expect(subject.find_by_route(route)).to eq nil
          end
        end
      end

      describe "#create_from_route" do
        it "creates a new controller, adding it to the members" do
          controller = subject.create_from_route(
            path: "/posts",
            controller: Object,
            action: "index",
            controller_name: "object"
          )

          expect(subject.first).to eq controller
          expect(controller.const).to eq Object
          expect(controller.name).to eq "object"
          expect(controller.endpoints).to \
            be_a Brainstem::ApiDocs::EndpointCollection
          expect(controller.endpoints.count).to eq 0
        end
      end

      describe "#find_or_create_from_route" do
        let!(:existing_controller) { subject.create_from_route(
          path: "/posts",
          controller: Object,
          action: "index",
          controller_name: "object"
        ) }

        context "when has matching controller" do
          let(:route) { { controller: Object, controller_name: "object" } }

          it "returns that controller" do
            subject.find_or_create_from_route(route)
            expect(subject.count).to eq 1
            expect(subject.last).to eq existing_controller
          end
        end

        context "when no matching controller" do
          let(:route) { { controller: TrueClass, controller_name: "true_class" } }

          it "returns a new controller" do
            new_controller = subject.find_or_create_from_route(route)
            expect(subject.count).to eq 2
            expect(subject.last).to eq new_controller
          end
        end
      end

      it_behaves_like "formattable"
      it_behaves_like "atlas taker"
    end
  end
end
