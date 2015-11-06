shared_examples "formattable" do
  describe "formatting" do
    let(:formatter) { Object.new }
    let(:formatters) { { markdown: formatter } }

    subject { described_class.new(formatters: formatters) }

    describe "#formatted_as" do
      it "looks up the formatter and calls that" do
        mock(formatter).call(subject, { test: true }) { "blah" }
        expect(subject.formatted_as(:markdown, test: true)).to eq "blah"
      end
    end
  end
end
