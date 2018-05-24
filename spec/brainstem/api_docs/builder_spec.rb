require 'spec_helper'
require 'brainstem/api_docs/builder'

module Brainstem
  module ApiDocs
    describe Builder do
      let(:dummy_environment_file) do
        File.expand_path('../../../../spec/dummy/rails.rb', __FILE__)
      end

      let(:default_options) do
        { args_for_introspector: { rails_environment_file: dummy_environment_file } }
      end

      let(:options) { {} }

      subject { Builder.new(default_options.merge(options)) }

      describe "#initialize" do
        let(:introspector_method) { Object.new }
        let(:options)             { { introspector_method: introspector_method } }

        before do
          any_instance_of(Builder) do |instance|
            stub(instance) do |k|
              k.build_introspector!
              k.build_atlas!
            end
          end
        end

        it "sets all valid values given to it as options" do
          expect(subject.introspector_method).to eq introspector_method
        end
      end

      describe "introspection" do
        let(:introspector_method)   { Object.new }
        let(:args_for_introspector) { { blah: true } }
        let(:introspector)          { Object.new }
        let(:options) do
          {
            args_for_introspector: args_for_introspector,
            introspector_method: introspector_method
          }
        end

        before do
          any_instance_of(Builder) do |instance|
            stub(instance) do |k|
              k.build_atlas!
            end
          end
        end

        it "passes the introspector method the introspector options" do
          mock(introspector_method).call(args_for_introspector)
          subject
        end

        it "creates an introspector" do
          stub(introspector_method).call(args_for_introspector) { introspector }
          expect(subject.introspector).to eq introspector
        end
      end

      describe "modeling" do
        let(:introspector)        { Object.new }
        let(:atlas_method)        { Object.new }
        let(:args_for_atlas)      { { blah: true } }
        let(:atlas)               { Object.new }
        let(:options)             { { atlas_method: atlas_method, args_for_atlas: args_for_atlas } }

        before do
          any_instance_of(Builder) do |instance|
            stub(instance) do |inst|
              inst.introspector { introspector }
              inst.build_introspector!
              inst.build_formatter!
            end
          end
        end

        it "passes the atlas method the introspector and the atlas options" do
          mock(atlas_method).call(introspector, args_for_atlas)
          subject
        end

        it "creates an atlas" do
          mock(atlas_method).call(introspector, args_for_atlas) { atlas }
          expect(subject.atlas).to eq atlas
        end
      end
    end
  end
end
