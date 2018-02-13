require 'spec_helper'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        describe "Helper" do
          let(:klass) { Class.new { include Helper } }

          subject { klass.new }

          describe "type_and_format" do
            context "when type is 'string'" do
              it "returns the correct type and format" do
                expect(subject.type_and_format('string')).to eq({ 'type' => 'string' })
              end
            end

            context "when type is 'boolean'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'boolean')).to eq({ 'type' => 'boolean' })
              end
            end

            context "when type is 'integer'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'integer')).to eq({ 'type' => 'integer', 'format' => 'int32' })
              end
            end

            context "when type is 'long'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'long')).to eq({ 'type' => 'integer', 'format' => 'int64' })
              end
            end

            context "when type is 'float'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'float')).to eq({ 'type' => 'number', 'format' => 'float' })
              end
            end

            context "when type is 'double'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'double')).to eq({ 'type' => 'number', 'format' => 'double' })
              end
            end

            context "when type is 'byte'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'byte')).to eq({ 'type' => 'string', 'format' => 'byte' })
              end
            end

            context "when type is 'binary'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'binary')).to eq({ 'type' => 'string', 'format' => 'binary' })
              end
            end

            context "when type is 'date'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'date')).to eq({ 'type' => 'string', 'format' => 'date' })
              end
            end

            context "when type is 'datetime'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'datetime')).to eq({ 'type' => 'string', 'format' => 'date-time' })
              end
            end

            context "when type is 'password'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'password')).to eq({ 'type' => 'string', 'format' => 'password' })
              end
            end

            context "when type is 'id'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'id')).to eq({ 'type' => 'integer', 'format' => 'int32' })
              end
            end

            context "when type is 'decimal'" do
              it "returns the correct type and format" do
                expect(subject.send(:type_and_format, 'decimal')).to eq({ 'type' => 'number', 'format' => 'float' })
              end
            end
          end
        end
      end
    end
  end
end