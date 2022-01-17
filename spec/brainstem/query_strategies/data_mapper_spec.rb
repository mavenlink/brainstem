require "spec_helper"

describe Brainstem::QueryStrategies::DataMapper do
  describe "#get_models" do
    it 'gets all models in the ids list sorted by list order, not the scope' do
      scope = Workspace.order(:id).limit(10)
      ids = scope.map(&:id).shuffle
      expect(ids.length).to be > 3

      models = subject.get_models(ids: ids, scope: scope)
      expect(models.map(&:id)).to eq ids
    end
  end
end