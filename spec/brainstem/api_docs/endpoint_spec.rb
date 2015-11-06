require 'spec_helper'
require 'brainstem/api_docs/endpoint'

module Brainstem
  module ApiDocs
    describe Endpoint do
      let(:lorem)   { "lorem ipsum dolor sit amet" }
      let(:options) { {} }
      subject       { described_class.new(options) }


      describe "#initialize" do
        it "yields self if given a block" do
          block = Proc.new { |s| s.path = "bork bork" }
          expect(described_class.new(&block).path).to eq "bork bork"
        end
      end


      describe "#to_h" do
        it "dumps the object to a hash" do
          instance = described_class.new do |b|
            b.path = "bork bork"
          end

          expect(instance.to_h).to eq({
            path: "bork bork",
            http_methods: nil,
            controller: nil,
            controller_name: nil,
            action: nil
          })
        end
      end


      describe "#merge_http_methods!" do
        let(:options) { { http_methods: %w(GET) } }

        it "adds http methods that are not already present" do

          expect(subject.http_methods).to eq %w(GET)
          subject.merge_http_methods!(%w(POST PATCH GET))
          expect(subject.http_methods).to eq %w(GET POST PATCH)
        end
      end


      describe "configured fields" do
        let(:controller)     { Object.new }
        let(:action)         { :show }

        let(:lorem)          { "lorem ipsum dolor sit amet" }
        let(:default_config) { {} }
        let(:show_config)    { {} }
        let(:nodoc)          { false }

        let(:configuration)  {
          {
            :_default => default_config,
            :show     => show_config,
          }
        }

        let(:options) { { controller: controller, action: action } }

        before do
          stub(controller).configuration { configuration }
        end


        describe "#nodoc?" do
          let(:show_config) { { nodoc: nodoc } }

          context "when nodoc" do
            let(:nodoc) { true }

            it "is true" do
              expect(subject.nodoc?).to eq true
            end
          end

          context "when documentable" do
            it "is false" do
              expect(subject.nodoc?).to eq false
            end
          end
        end


        describe "#title" do
          context "when present" do
            let(:show_config) { { title: { info: lorem, nodoc: nodoc } } }

            context "when nodoc" do
              let(:nodoc) { true }

              it "uses the action name" do
                expect(subject.title).to eq "Show"
              end
            end

            context "when documentable" do
              it "formats the title as an h4" do
                expect(subject.title).to eq lorem
              end
            end
          end

          context "when absent" do
            it "falls back to the action name" do
              expect(subject.title).to eq "Show"
            end
          end
        end


        describe "#description" do
          context "when present" do
            let(:show_config) { { description: { info: lorem, nodoc: nodoc } } }

            context "when nodoc" do
              let(:nodoc) { true }

              it "shows nothing" do
                expect(subject.description).to be_empty
              end
            end

            context "when not nodoc" do
              it "shows the description" do
                expect(subject.description).to eq lorem
              end
            end
          end

          context "when not present" do
            it "shows nothing" do
              expect(subject.description).to be_empty
            end
          end
        end


        describe "#valid_params" do
          xit "does something"
        end


        describe "#root_param_keys" do
          xit "does something"
        end


        describe "#valid_presents" do
          xit "does something"
        end


        describe "#presenter" do
        end


        describe "#contextual_documentation" do
          xit "does something"
        end


        describe "#key_with_default_fallback" do
          xit "does something"
        end
      end


      describe "#sort" do
        actions = %w(index show create update delete articuno zapdos moltres)

        actions.each do |axn|
          let(axn.to_sym) { described_class.new(action: axn.to_sym) }
        end

        let(:axns) { actions.map {|axn| send(axn.to_sym) } }

        it "orders appropriately" do
          sorted = axns.reverse.sort
          expect(sorted[0]).to eq index
          expect(sorted[1]).to eq show
          expect(sorted[2]).to eq create
          expect(sorted[3]).to eq update
          expect(sorted[4]).to eq delete
          expect(sorted[5]).to eq articuno
          expect(sorted[6]).to eq moltres
          expect(sorted[7]).to eq zapdos
        end
      end


      describe "#presenter_title" do
        let(:presenter) { mock!.title.returns(lorem).subject }
        let(:options)   { { presenter: presenter } }

        it "returns the presenter's title" do
          expect(subject.presenter_title).to eq lorem
        end
      end


      describe "#relative_presenter_path_from_controller" do
        let(:presenter) {
          mock!
            .suggested_filename(:markdown)
            .returns("models/sprocket_widget.markdown")
            .subject
        }

        let(:controller) {
          mock!
            .suggested_filename(:markdown)
            .returns("controllers/api/v1/sprocket_widgets_controller.markdown")
            .subject
        }

        let(:options) { { presenter: presenter, controller: controller } }


        it "returns a relative path" do
          expect(subject.relative_presenter_path_from_controller(:markdown)).to \
            eq "../../../models/sprocket_widget.markdown"
        end
      end


      it_behaves_like "formattable"
    end
  end
end
