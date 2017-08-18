require 'spec_helper'

describe Brainstem::QueryStrategies::FilterAndSearch do
  let(:bob) { User.find_by_username('bob') }
  let(:jane) { User.find_by_username('jane') }

  let(:options) { {
    primary_presenter: CheesePresenter.new,
    table_name: 'cheeses',
    default_per_page: 20,
    default_max_per_page: 200,
    default_max_filter_and_search_page: 500,
    params: params
  } }

  let(:default_params) { {
    "owned_by" => bob.id.to_s,
  } }

  describe '#execute' do
    let(:owned_by_bob) { Cheese.owned_by(bob.id) }
    let(:owned_by_jane) { Cheese.owned_by(jane.id) }

    context 'when searching' do
      let(:search_params) { default_params.merge(search: 'toot, otto, toot') }
      let(:filtered_search_results) { $search_results - owned_by_jane.map(&:id) }

      before do
        $search_results = Cheese.all.map(&:id).shuffle

        CheesePresenter.search do |_, _|
          [$search_results, $search_results.length]
        end

        CheesePresenter.filter(:owned_by) { |scope, user_id| scope.owned_by(user_id.to_i) }
      end

      context 'with limit and offset' do
        let(:limit) { 5 }
        let(:offset) { 5 }
        let(:params) { search_params.merge(limit: limit, offset: offset)}
        let(:limited_and_offset_filtered_search_results) { filtered_search_results.drop(offset).first(limit) }

        it 'returns the filtered search results, ordered by search, with the correct limit and offset' do
          results, count = described_class.new(options).execute(Cheese.all)
          expect(count).to eq(filtered_search_results.count)
          expect(results.map(&:id)).to eq(limited_and_offset_filtered_search_results)
        end
      end

      context 'with page and per_page' do
        let(:per_page) { 7 }

        context 'with page 1' do
          let(:params) { search_params.merge(page: 1, per_page: per_page)}
          let(:paginated_filtered_search_results) { filtered_search_results.first(per_page) }

          it 'returns the filtered search results, ordered by search, first page' do
            results, count = described_class.new(options).execute(Cheese.all)
            expect(count).to eq(filtered_search_results.count)
            expect(results.map(&:id)).to eq(paginated_filtered_search_results)
          end
        end

        context 'with page 2' do
          let(:params) { search_params.merge(page: 2, per_page: per_page) }
          let(:paginated_filtered_search_results) { filtered_search_results.drop(per_page).first(per_page) }

          it 'returns the filtered search results, ordered by search, second page' do
            results, count = described_class.new(options).execute(Cheese.all)
            expect(count).to eq(filtered_search_results.count)
            expect(results.map(&:id)).to eq(paginated_filtered_search_results)
          end
        end
      end
    end

    context 'when not searching' do
      let(:per_page) { 7 }
      let(:params) { default_params.merge(per_page: per_page) }
      let(:filtered_and_sorted_results) { owned_by_bob.map(&:id).sort }

      before do
        CheesePresenter.filter(:owned_by) { |scope, user_id| scope.owned_by(user_id.to_i) }
        CheesePresenter.sort_order(:id)   { |scope, direction| scope.order("cheeses.id #{direction}") }
      end

      it 'takes the intersection of the search and filter results' do
        results, count = described_class.new(options).execute(Cheese.all)
        expect(count).to eq(Cheese.owned_by(bob.id.to_s).count)
        expect(results.map(&:id)).to eq(filtered_and_sorted_results.first(per_page))
      end

      it 'applies ordering to the scope' do
        options[:params]["order"] = 'id:desc'
        proxy.instance_of(Brainstem::Presenter).apply_ordering_to_scope(anything, anything).times(1)
        results, count = described_class.new(options).execute(Cheese.all)
        expect(count).to eq(Cheese.owned_by(bob.id.to_s).count)
        expect(results.map(&:id)).to eq(filtered_and_sorted_results.reverse.first(per_page))
      end
    end
  end
end
