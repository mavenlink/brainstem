require 'spec_helper'

describe Brainstem::QueryStrategies::FilterAndSearch do
  let(:bob) { User.find_by_username('bob') }

  let(:params) { {
    "owned_by" => bob.id.to_s,
    per_page: 7,
    page: 1,
    search: 'toot, otto, toot',
    order: 'description:desc'
  } }

  let(:options) { {
    primary_presenter: CheesePresenter.new,
    table_name: 'cheeses',
    default_per_page: 20,
    default_max_per_page: 200,
    default_max_filter_and_search_page: 500,
    params: params
  } }

  let(:subject) { described_class.new(options) }

  describe '#execute' do
    before do
      CheesePresenter.search do |string, options|
        [[2,3,4,5,6,8,9,10,11,12], 11]
      end

      CheesePresenter.filter(:owned_by) { |scope, user_id| scope.owned_by(user_id.to_i) }
    end

    it 'takes the intersection of the search and filter results' do
      results, count = subject.execute(Cheese.unscoped)
      expect(count).to eq(8)
      expect(results.pluck(:id)).to eq([2,3,4,5,8,10,11])
    end
  end
end
