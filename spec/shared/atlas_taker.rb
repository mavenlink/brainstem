shared_examples "atlas taker" do
  describe "#initialize" do
    it "requires an atlas" do
      expect { described_class.new }.to raise_error ArgumentError
      expect { described_class.new(atlas) }.not_to raise_error
    end
  end

  describe "#find_by_class" do
    let(:klass) { Class.new }

    it "delegates to the atlas" do
      mock(atlas).find_by_class(klass)
      subject.find_by_class(klass)
    end
  end
end

