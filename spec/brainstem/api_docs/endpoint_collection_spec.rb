require 'spec_helper'
require 'brainstem/api_docs/endpoint_collection'

module Brainstem
  module ApiDocs
    describe EndpointCollection do
      let(:atlas)    { Object.new }
      let(:options)  { {} }
      let(:endpoint) { Object.new }

      subject { described_class.new(atlas, options) }

      describe "#find_from_route" do
        let(:controller) { stub!.const { Object }.subject }

        before do
          stub(endpoint) do |c|
            c.path            { "/posts" }
            c.http_methods    { ["GET", "POST"] }
            c.controller      { controller }
            c.controller_name { "object" }
            c.action          { "index" }
          end

          subject << endpoint
        end

        context "when matches route" do
          it "returns the matching controller" do
            route = { controller: Object, path: "/posts", action: "index" }
            expect(subject.find_by_route(route)).to eq endpoint
          end
        end

        context "when does not match route" do
          it "returns nil" do
            routes = [
              { controller: TrueClass, path: "/posts", action: "index" },
              { controller: Object,    path: "/wrong", action: "index" },
              { controller: Object,    path: "/posts", action: "wrong" },
            ]

            routes.each do |route|
              expect(subject.find_by_route(route)).to eq nil
            end
          end
        end
      end

      describe "#create_from_route" do
        it "creates a new endpoint, adding it to the members" do
          controller = Object.new

          endpoint = subject.create_from_route({
            path:            "/posts",
            http_methods:    ["GET"],
            controller_name: "object",
            action:          "index",
          }, controller)

          expect(subject.first).to eq endpoint
          expect(endpoint.controller).to eq controller
          expect(endpoint.controller_name).to eq "object"
          expect(endpoint.action).to eq "index"
          expect(endpoint.path).to eq "/posts"
          expect(endpoint.http_methods).to eq ["GET"]
        end
      end

      describe "#only_documentable" do
        let(:endpoint_2) { Object.new }

        before do
          stub(endpoint).nodoc? { false }
          stub(endpoint_2).nodoc? { true }

          subject << endpoint
          subject << endpoint_2
        end

        it "returns a new collection with members that are not nodoc" do
          new_clxn = subject.only_documentable

          expect(new_clxn).to be_a described_class
          expect(new_clxn).to include endpoint
          expect(new_clxn).not_to include endpoint_2
        end
      end

      describe "#with_declared_presented_class" do
        let(:endpoint_2) { Object.new }

        before do
          stub(endpoint).declared_presented_class { Class.new }
          stub(endpoint_2).declared_presented_class { nil }
          subject << endpoint
          subject << endpoint_2
        end

        it "returns a new collection with members that have declared presents" do
          new_clxn = subject.with_declared_presented_class

          expect(new_clxn).to be_a described_class
          expect(new_clxn).to include endpoint
          expect(new_clxn).not_to include endpoint_2
        end
      end

      describe "#with_actions_in_controller" do
        let(:endpoint_2) { Object.new }
        let(:const) do
          Class.new do
            def show
            end
          end
        end

        before do
          stub(endpoint).action { :show }
          stub(endpoint_2).action { :index }
          subject << endpoint
          subject << endpoint_2
        end

        it "returns a new collection with members that the const responds to" do
          new_clxn = subject.with_actions_in_controller(const)

          expect(new_clxn).to be_a described_class
          expect(new_clxn).to include endpoint
          expect(new_clxn).not_to include endpoint_2
        end
      end

      it_behaves_like "formattable"
      it_behaves_like "atlas taker"
    end
  end
end
