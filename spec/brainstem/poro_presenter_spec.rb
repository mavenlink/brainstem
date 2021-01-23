require "spec_helper"

describe 'presenting POROs' do
  HotDog = Struct.new(:condiment, :length, :id) do
    def self.table_name

    end
  end

  let!(:poro_presenter) do
    Class.new(Brainstem::PoroPresenter) do
      presents HotDog
      brainstem_key :hot_dogs

      fields do
        field :condiment, :string
        field :length, :integer
      end
    end
  end

  it 'can present non-AR objects' do
    result = poro_presenter.new.group_present([HotDog.new('mustard', 42, 17)]).first
    expect(result["condiment"]).to eq("mustard")
    expect(result["length"]).to eq(42)
  end

  it "can present a collection of POROs" do
    result = Brainstem.presenter_collection.presenting("hot_dogs") { [HotDog.new('mustard', 42)] }
    expect(result["hot_dogs"]).to_not be_empty
  end

  it "can assign ids" do
    result = Brainstem.presenter_collection.presenting("hot_dogs") { [HotDog.new('mustard', 42, 666)] }
    expect(result["hot_dogs"].keys.first).to eq(666)
  end
end
