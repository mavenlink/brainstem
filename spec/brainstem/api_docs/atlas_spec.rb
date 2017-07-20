require 'spec_helper'
require 'brainstem/api_docs/atlas'
require 'dummy/rails'

module Brainstem
  module ApiDocs
    describe Atlas do
      let(:introspector) { Object.new }

      subject { Atlas.new(introspector) }

      describe "#initialize" do
        describe "mapping" do
          before do
            stub(introspector).valid? { true }
          end

          it "parses routes" do
            any_instance_of(Atlas) do |instance|
              mock(instance).parse_routes!
              stub(instance).extract_presenters!
              stub(instance).validate!
            end

            subject
          end

          it "extracts presenters" do
            any_instance_of(Atlas) do |instance|
              stub(instance).parse_routes!
              mock(instance).extract_presenters!
              stub(instance).validate!
            end

            subject
          end
        end


        describe "validation" do
          before do
            any_instance_of(Atlas) do |instance|
              stub(instance).parse_routes!
              stub(instance).extract_presenters!
            end
          end

          describe "when atlas is invalid" do
            before do
              stub.any_instance_of(Atlas).valid? { false }
            end

            it "raises an error" do
              expect { subject }.to raise_error InvalidAtlasError
            end
          end

          describe "when atlas is valid" do
            before do
              stub.any_instance_of(Atlas).valid? { true }
            end

            it "does not raise an error" do
              expect { subject }.not_to raise_error
            end

          end
        end
      end

      describe "#parse_routes!" do
        let(:route_1) { {
          path:            "/endpoint1",
          http_methods:    ["POST"],
          controller:      FakeDescendantController,
          controller_name: "fake_descendant",
          action:          "create" } }

        let(:route_2) { {
          path:            "/endpoint2",
          http_methods:    ["GET"],
          controller:      FakeDescendantController,
          controller_name: "fake_descendant",
          action:          "show" } }

        before do
          any_instance_of(Atlas) do |instance|
            stub(instance).extract_presenters!
            stub(instance).validate!
          end

          stub(introspector) do |i|
            i.routes { [ route_1, route_2 ] }
            i.controllers { [ FakeDescendantController ] }
            i.presenters { }
            i.valid? { true }
          end

        end

        context "when route is valid" do
          it "constructs an Endpoint" do
            expect(subject.endpoints.count).to eq 2
            expect(subject.endpoints).to all(be_an(Endpoint))
          end

          it "adds the endpoint to the controller" do
            expect(subject.controllers.first.endpoints.count).to eq 2
            expect(subject.controllers.first.endpoints).to all(be_an(Endpoint))
          end

          context "when controller not in controllers list" do
            let(:route_2) { {
              path:            "/endpoint2",
              http_methods:    ["GET"],
              controller:      TrueClass,
              controller_name: "true_class",
              action:          "show" } }

            it "discards the route" do
              expect(subject.endpoints.count).to eq 1
            end
          end

          context "when controller does not match all passed matches" do
            let(:route_2) { {
              path:            "/endpoint2",
              http_methods:    ["GET"],
              controller:      TrueClass,
              controller_name: "true_class",
              action:          "show" } }

            before do
              stub.any_instance_of(Atlas)
                .controller_matches { [ Regexp.new('FakeDescendant', 'i') ] }
            end

            it "discards the route" do
              expect(subject.endpoints.count).to eq 1
            end
          end

          context "when controller does match all passed matches" do
            before do
              stub.any_instance_of(Atlas)
                .controller_matches { [ Regexp.new('FakeDescendant', 'i') ] }
            end

            it "keeps the route" do
              expect(subject.endpoints.count).to eq 2
            end
          end

          context "when an Endpoint for that route already exists, but with a different HTTP verb" do
            let(:route_2) { {
              path:            "/endpoint1",
              http_methods:    ["PATCH"],
              controller:      FakeDescendantController,
              controller_name: "fake_descendant",
              action:          "create" } }

            it "merges the route" do
              expect(subject.endpoints.count).to eq 1
              expect(subject.endpoints.first.http_methods).to eq ["POST", "PATCH"]
            end
          end
        end


        context "when a route is invalid" do
          let(:route_2) { {
            path: "/endpoint2",
            http_methods: ["GET"],
            controller: TrueClass,
            controller_name: "plainly_erroneous",
            action: "show" } }

          it "skips that route" do
            expect(subject.endpoints.count).to eq 1
            expect(subject.endpoints).to all(be_an(Endpoint))
          end
        end

        context "when all routes are invalid" do
          let(:route_1)   { {
            path:            "/endpoint1",
            http_methods:    ["POST"],
            controller:      TrueClass,
            controller_name: "true_class",
            action:          "create" } }

          let(:route_2)   { {
            path:            "/endpoint2",
            http_methods:    ["GET"],
            controller:      TrueClass,
            controller_name: "true_class",
            action:          "show" } }

          it "has an empty endpoints" do
            expect(subject.endpoints.count).to eq 0
          end
        end
      end


      describe "#extract_presenters!" do
        let(:endpoint_1)           { Object.new }
        let(:endpoint_2)           { Object.new }
        let(:presenter)            { Object.new }
        let(:target_class)         { Class.new }
        let(:presenter_collection) { Object.new }

        before do
          # This set-up is a bit of a smell.
          stub(endpoint_1).declared_presented_class { target_class }
          stub(endpoint_2).declared_presented_class { Class.new }

          stub(target_class).to_s { "TargetClass" }

          any_instance_of(described_class) do |instance|
            stub(instance).parse_routes!
            stub(instance).validate!

            stub(instance).valid_presenter_pairs { {
              "TargetClass" => target_class
            } }

            stub(instance).presenters { presenter_collection }
            stub(instance).endpoints { [ endpoint_1, endpoint_2 ] }
          end
        end

        it "creates a presenter for each valid presenter pair" do
          stub(endpoint_1).presenter=(presenter)
          mock(presenter_collection)
            .find_or_create_from_presenter_collection("TargetClass", target_class) { presenter }

          subject
        end

        it "sets the presenter on each endpoint that presents the same" do
          mock(endpoint_1).presenter=(presenter)
          dont_allow(endpoint_2).presenter=(presenter)

          stub(presenter_collection)
            .find_or_create_from_presenter_collection("TargetClass", target_class) { presenter }

          subject
        end
      end


      describe "#valid?" do
        before do
          any_instance_of(Atlas) do |instance|
            stub(instance) do |i|
              i.parse_routes!
              i.extract_presenters!
              i.validate!
            end
          end
        end

        context "when has at least one endpoint" do
          before do
            stub(subject).endpoints { [ Object.new ] }
          end

          it "is valid" do
            expect(subject.send(:valid?)).to eq true
          end
        end

        context "When has no endpoints" do
          before do
            stub(subject).endpoints { [ ] }
          end

          it "is invalid" do
            expect(subject.send(:valid?)).to eq false
          end
        end
      end


      describe "#allow_route?" do
        before do
          any_instance_of(Atlas) do |instance|
            stub(instance) do |i|
              i.parse_routes!
              i.extract_presenters!
              i.validate!
            end
          end

          stub(introspector) do |instance|
            instance.controllers  { [ FakeDescendantController ] }
          end
        end

        context "when controller not in the controllers list" do
          it "is false" do
            expect(subject.send(:allow_route?, controller: FakeNonDescendantController)).to eq false
          end
        end

        context "when controller in the controllers list" do
          context "when matches all controller_matches" do
            before do
              stub.any_instance_of(Atlas).controller_matches do
                [ Regexp.new('descendant', 'i') ]
              end
            end

            it "is true" do
              expect(subject.send(:allow_route?, controller: FakeDescendantController)).to eq true
            end
          end

          context "when controller does not match all controller_matches" do
            before do
              stub.any_instance_of(Atlas).controller_matches do
                [ Regexp.new('wildly_inaccurate_regexp_match', 'i') ]
              end
            end

            it "is false" do
              expect(subject.send(:allow_route?, controller: FakeDescendantController)).to eq false
            end
          end
        end
      end


      describe "#find_by_class" do
        before do
          any_instance_of(Atlas) do |instance|
            stub(instance) do |i|
              i.parse_routes!
              i.extract_presenters!
              i.validate!
            end
          end
        end

        it "delegates to the resolver" do
          mock(subject.resolver).find_by_class(nil)
          subject.find_by_class(nil)
        end
      end
    end
  end
end
