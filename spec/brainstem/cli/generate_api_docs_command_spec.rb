require 'spec_helper'
require 'brainstem/cli/generate_api_docs_command'

module Brainstem
  module CLI
    describe GenerateApiDocsCommand do
      let(:args) { [ ] }

      subject { GenerateApiDocsCommand.new(args) }

      describe "options" do
        xcontext "when --markdown" do
          let(:args) { %w(--markdown) }

          it "sets sink options method to the MarkdownFormatter instantiation" do
            expect(subject.options[:builder]).to have_key :formatter_method
            expect(subject.options[:builder][:formatter_method]).to be_a Method

            # TODO: If we need to go further here, we can implement .call on
            # the formatter:
            # expect(subject.options[:builder][:formatter_method].owner).to \
            #   eq Brainstem::ApiDocs::Formatters::AbstractFormatter
          end
        end

        context "when --multifile-presenters-and-controllers" do
          let(:args) { %w(--multifile-presenters-and-controllers) }

          it "sets sink to a ControllerPresenterMultifileSink" do
            expect(subject.options).to have_key :sink
            expect(subject.options[:sink][:method].call).to be_a \
              Brainstem::ApiDocs::Sinks::ControllerPresenterMultifileSink
          end
        end

        context "when --output-dir" do
          let(:args) { %w(--output-dir=./blah) }

          it "sets the write_path option of the sink" do
            expect(subject.options[:sink][:options][:write_path]).to eq "./blah"
          end
        end

        context "when --api-version" do
          let(:args) { %w(--api-version=2.0.0 ) }

          it "sets the api version option of the sink" do
            expect(subject.options[:sink][:options][:api_version]).to eq '2.0.0'
          end
        end

        context "when --controller-matches" do
          let(:matches) { subject.options[:builder][:args_for_atlas][:controller_matches] }

          context "when just one match specified" do
            let(:args) { %w(--controller-matches=/workspaces/) }
            it "creates a case-insensitive regexp from the in-between-slash info" do
              mock.proxy(Regexp).new('workspaces', 'i')
              subject
            end

            it "appends to the match terms" do
              expect(matches).to include Regexp.new('workspaces', 'i')
            end
          end

          context "when multiple matches specified" do
            let(:args) { %w(--controller-matches=/workspaces/ --controller-matches=/extra/) }

            it "allows additional specification and merges the arguments" do
              expect(matches).to include Regexp.new('workspaces', 'i')
            end
          end
        end

        context "when --open-api-specification" do
          let(:args) { %w(--open-api-specification) }

          it "sets sink to a OpenApiSpecificationSink" do
            expect(subject.options).to have_key :sink
            expect(subject.options[:sink][:method].call).to be_a \
              Brainstem::ApiDocs::Sinks::OpenApiSpecificationSink
          end
        end
      end


      describe "execution" do
        context "when no sink provided" do
          before do
            any_instance_of(described_class) do |instance|
              stub(instance).default_sink_method { nil }
            end
          end

          it "raises an error" do
            expect { subject.call }.to raise_error \
              Brainstem::ApiDocs::NoSinkSpecifiedException
          end
        end

        context "when sink specified" do
          before do
            stub(subject).ensure_sink_specified!
          end

          describe "builder" do
            let(:builder_options) { { builder: { test: 123 } } }

            before do
              stub(subject).present_atlas!
              stub(subject).builder_options { builder_options }
            end

            it "creates a new builder with builder options passed" do
              mock(Brainstem::ApiDocs::Builder).new(builder_options)
              subject.call
            end
          end

          describe "presentation" do
            it "sends the atlas to the sink" do
              atlas       = Object.new
              builder     = mock!.atlas.returns(atlas).subject
              sink        = mock!.<<(atlas).subject
              sink_method = mock!.call({ test: 123 }).returns(sink).subject

              stub(subject) do |sub|
                sub.construct_builder!
                sub.builder { builder }
                sub.sink_options { { test: 123 } }
                sub.sink_method { sink_method }
              end

              subject.call
            end
          end
        end
      end

    end
  end
end
