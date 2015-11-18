require 'spec_helper'
require 'brainstem/api_docs/introspectors/rails_introspector'

module Brainstem
  module ApiDocs
    module Introspectors
      describe RailsIntrospector do
        let(:dummy_environment_file) do
          File.expand_path('../../../../../spec/dummy/rails.rb', __FILE__)
        end

        let(:described_klass) { RailsIntrospector }
        let(:default_args)    { { rails_environment_file: dummy_environment_file } }

        subject do
          RailsIntrospector.send(:new, default_args)
        end


        context "when cannot find the environment file" do
          describe "#load_environment!" do
            subject { described_klass.send(:new) }

            before do
            #   In the event that we've already loaded the environment through
            #   random ordering of specs, we want to force a reload.
            #
            #   For some reason, this has stopped being needed.
              Object.send(:remove_const, :Rails) if defined?(Rails)
            end

            it "raises an error" do
              # Testing this within Brainstem should fail.

              expect { subject.send(:load_environment!) }
                .to raise_error IncorrectIntrospectorForAppException
            end
          end
        end

        context "when can find the entrypoint file" do
          describe "#load_environment!" do
            context "when introspector is invalid" do
              before do
                stub(subject).valid? { false }
              end

              it "raises an error" do
                expect { subject.send(:load_environment!) }.to \
                  raise_error InvalidIntrospectorError
              end
            end

            context "when introspector is valid" do
              before do
                stub(subject).valid? { true }
              end

              it "does not raise an error" do
                expect { subject.send(:load_environment!) }.not_to raise_error
              end

              it "does not load the file if Rails is defined" do
                # Ensure that this has been sent already.
                subject.send(:load_environment!)

                dont_allow(subject).rails_environment_file
                mock(subject).env_already_loaded? { true }

                subject.send(:load_environment!)
              end
            end
          end

          describe "#presenters" do
            before do
              stub.any_instance_of(described_klass).validate!
            end

            subject do
              described_klass.with_loaded_environment(
                default_args.merge(base_presenter_class: "::FakeBasePresenter")
              )
            end


            it "allows the specification of a custom base_presenter_class" do
              expect(subject.send(:base_presenter_class).to_s)
                .to eq "::FakeBasePresenter"
            end

            it "returns the descendants of the base presenter class" do
              expect(subject.presenters).to eq [FakeDescendantPresenter]
            end
          end

          describe "#controllers" do
            before do
              stub.any_instance_of(described_klass).validate!
            end

            subject do
              described_klass.with_loaded_environment(
                default_args.merge(base_controller_class: "::FakeBaseController")
              )
            end


            it "allows the specification of a custom base_controller_class" do
              expect(subject.send(:base_controller_class).to_s)
                .to eq "::FakeBaseController"
            end

            it "returns the descendants of the base controller class" do
              expect(subject.controllers).to eq [FakeDescendantController]
            end
          end

          describe "#routes" do
            let(:a_proc) { Object.new }

            before do
              stub.any_instance_of(described_klass).validate!
            end

            context "with dummy method" do
              subject do
                described_klass.with_loaded_environment(
                  default_args.merge(routes_method: a_proc)
                )
              end

              it "allows the specification of a custom method to return the routes" do
                expect(subject.send(:routes_method)).to eq a_proc
              end

              it "calls the routes method to return the routes" do
                mock(a_proc).call
                subject.routes
              end
            end

            context "with fake (but realistic) data" do
              subject do
                described_klass.with_loaded_environment(default_args)
              end

              it "skips the entry if it does not have a valid controller" do
                expect(subject.routes.count).to eq 1
              end

              it "adds the controller constant" do
                expect(subject.routes.first[:controller]).to eq FakeDescendantController
              end

              it "reports the controller name" do
                expect(subject.routes.first[:controller_name]).to eq "fake_descendant"
              end

              it "transforms the HTTP method regexp into a list of verbs" do
                expect(subject.routes.first[:http_methods]).to eq %w(GET POST)
              end

            end
          end
        end
      end
    end
  end
end
