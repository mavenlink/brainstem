require 'spec_helper'

describe Brainstem::QueryStrategies::FilterAndSearch do
  let(:bob) { User.find_by_username('bob') }
  let(:jane) { User.find_by_username('jane') }

  let(:default_params) { {
    "owned_by" => bob.id.to_s,
    search: 'toot, otto, toot',
  } }

  let(:options) { {
    primary_presenter: CheesePresenter.new,
    table_name: 'cheeses',
    default_per_page: 20,
    default_max_per_page: 200,
    default_max_filter_and_search_page: 500,
    params: params
  } }

  def run_query
    described_class.new(options).execute(Cheese.all)
  end

  describe '#execute' do
    let(:owned_by_bob) { Cheese.owned_by(bob.id)}
    let(:owned_by_jane) { Cheese.owned_by(jane.id)}

    before do
      $search_results = Cheese.all.pluck(:id).shuffle
    end

    before do
      CheesePresenter.search do |_, _|
        [$search_results, $search_results.count]
      end

      CheesePresenter.filter(:owned_by) { |scope, user_id| scope.owned_by(user_id.to_i) }
      CheesePresenter.sort_order(:id)   { |scope, direction| scope.order("cheeses.id #{direction}") }
    end

    context 'when an order is specified' do
      let(:order) { 'id:asc' }
      let(:params) { default_params.merge({ order: order })}
      let(:expected_ordered_ids) { owned_by_bob.order("cheeses.id ASC").pluck(:id) }

      it 'returns the filtered, ordered search results' do
        results, count = run_query
        expect(count).to eq(owned_by_bob.count)
        expect(results.map(&:id)).to eq(expected_ordered_ids)
      end

      context 'with limit and offset params' do
        let(:limit) { 2 }
        let(:offset) { 4 }
        let(:params) { default_params.merge({ order: order, limit: limit, offset: offset })}
        let(:expected_paginated_ids) { expected_ordered_ids.drop(offset).first(limit) }

        it 'returns the filtered, ordered, paginated results' do
          results, count = run_query
          expect(count).to eq(owned_by_bob.count)
          expect(results.map(&:id)).to eq(expected_paginated_ids)
        end
      end

      context 'with page and per_page params' do
        let(:page) { 2 }
        let(:per_page) { 3 }
        let(:params) { default_params.merge({ order: order, page: page, per_page: per_page })}
        let(:expected_paginated_ids) { expected_ordered_ids.drop(per_page).first(per_page) }

        it 'returns the filtered, ordered, paginated results' do
          results, count = run_query
          expect(count).to eq(owned_by_bob.count)
          expect(results.map(&:id)).to eq(expected_paginated_ids)
        end
      end
    end

    context 'when no order is specified' do
      let(:params) { default_params }
      let(:expected_ordered_ids) { $search_results - owned_by_jane.pluck(:id) }

      before do
        expect(params[:order]).not_to be_present
      end

      it 'returns the filtered results ordered by search' do
        results, count = run_query
        expect(count).to eq(owned_by_bob.count)
        expect(results.map(&:id)).to eq(expected_ordered_ids)
      end

      it 'only does two database queries' do
        expect { run_query }.to make_database_queries(count: 2)
      end

      context 'with limit and offset params' do
        let(:limit) { 2 }
        let(:offset) { 4 }
        let(:params) { default_params.merge({ limit: limit, offset: offset })}
        let(:expected_paginated_ids) { expected_ordered_ids.drop(offset).first(limit) }

        it 'returns the filtered, ordered, paginated results' do
          results, count = run_query
          expect(count).to eq(owned_by_bob.count)
          expect(results.map(&:id)).to eq(expected_paginated_ids)
        end
      end

      context 'with page and per_page params' do
        let(:page) { 2 }
        let(:per_page) { 3 }
        let(:params) { default_params.merge({ page: page, per_page: per_page })}
        let(:expected_paginated_ids) { expected_ordered_ids.drop(per_page).first(per_page) }

        it 'returns the filtered, ordered, paginated results' do
          results, count = run_query
          expect(count).to eq(owned_by_bob.count)
          expect(results.map(&:id)).to eq(expected_paginated_ids)
        end
      end
    end
  end
end
