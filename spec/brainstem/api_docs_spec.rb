require 'spec_helper'
require 'brainstem/api_docs'

module Brainstem
  describe ApiDocs do
    let(:lorem) { "lorem ipsum dolor sit amet" }


    describe "configuration" do
      describe "formatters" do
        it "has a formatters constant" do
          expect(Brainstem::ApiDocs::FORMATTERS).to be_a(Hash)
        end
      end

      %w(
        base_path
        controller_filename_pattern
        presenter_filename_pattern
        controller_filename_link_pattern
        presenter_filename_link_pattern
        write_path
        output_extension
        base_presenter_class
        base_controller_class
        document_empty_presenter_associations
        document_empty_presenter_filters
      ).each do |meth|
        describe meth do
          before do
            @original = Brainstem::ApiDocs.public_send(meth)
          end

          after do
            Brainstem::ApiDocs.public_send("#{meth}=", @original)
          end

          it "can be set and read" do
            Brainstem::ApiDocs.public_send("#{meth}=", lorem)
            expect(Brainstem::ApiDocs.public_send(meth)).to eq lorem
          end
        end
      end
    end

    describe "filename link patterns" do
      it 'defaults to the filename pattern' do
        expect(Brainstem::ApiDocs.public_send("controller_filename_link_pattern")).
          to eq(Brainstem::ApiDocs.public_send("controller_filename_pattern"))

        expect(Brainstem::ApiDocs.public_send("presenter_filename_link_pattern")).
          to eq(Brainstem::ApiDocs.public_send("presenter_filename_pattern"))
      end
    end
  end
end
