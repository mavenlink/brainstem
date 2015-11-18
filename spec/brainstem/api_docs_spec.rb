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
        controller_filename_pattern
        presenter_filename_pattern
        base_path
        output_extension
        base_presenter_class
        base_controller_class
      ).each do |meth|
        describe meth do
          it "can be set and read" do
            Brainstem::ApiDocs.public_send("#{meth}=", lorem)
            expect(Brainstem::ApiDocs.public_send(meth)).to eq lorem
          end
        end
      end
    end


  end
end
