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

  it_behaves_like Brainstem::QueryStrategies::BaseStrategy

  describe '#execute' do
    def run_query
      described_class.new(options).execute(Cheese.all)
    end

    let(:owned_by_bob) { Cheese.owned_by(bob.id)}
    let(:owned_by_jane) { Cheese.owned_by(jane.id)}

    before do
      @search_results = search_results = Cheese.all.pluck(:id).shuffle

      CheesePresenter.search do
        [search_results, search_results.count]
      end

      CheesePresenter.filter(:owned_by, :integer) { |scope, user_id| scope.owned_by(user_id.to_i) }
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

      if(ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql/i)
        describe 'mysql_use_calc_found_rows' do
          context 'when using mysql_use_calc_found_rows' do
            before do
              Brainstem.mysql_use_calc_found_rows = true
              expect(Brainstem.mysql_use_calc_found_rows).to eq(true)
            end

            after do
              Brainstem.mysql_use_calc_found_rows = false
            end

            it 'returns the results without issuing a second query' do
              expect { run_query }.
                  not_to make_database_queries({ count: 1, matching: "SELECT COUNT(*) FROM" })

              expect { run_query }.
                to make_database_queries({ count: 1, matching: /SELECT\s+DISTINCT SQL_CALC_FOUND_ROWS cheeses.id FROM/ }).
                and make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })

              _, count = run_query
              expect(count).to eq(owned_by_bob.count)
            end
          end

          context 'when not using mysql_use_calc_found_rows' do
            before do
              expect(Brainstem.mysql_use_calc_found_rows).to eq(false)
            end

            it 'returns the results by issuing a count query' do
              expect { run_query }.
                to make_database_queries({ count: 1, matching: "SELECT COUNT(*) FROM" })

              expect { run_query }.
                not_to make_database_queries({ count: 1, matching: /SELECT\s+DISTINCT SQL_CALC_FOUND_ROWS cheeses.id FROM/ })

              expect { run_query }.
                not_to make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })
            end
          end
        end
      end
    end

    context 'when no order is specified' do
      let(:params) { default_params }
      let(:expected_ordered_ids) { @search_results - owned_by_jane.pluck(:id) }

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

  describe '#ordering?' do
    context 'when the order param is passed' do
      let(:params) { default_params.merge({ order: 'canadianness' })}

      context 'and it exists on the presenter' do
        before do
          CheesePresenter.sort_order(:canadianness) { |scope, direction| scope.order("cheeses.hockey #{direction}") }
          expect(CheesePresenter.configuration[:sort_orders][:canadianness]).to be_present
        end

        it 'returns true' do
          query_strat = described_class.new(options)
          expect(query_strat.send(:ordering?)).to eq(true)
        end
      end

      context 'and it does not exist on the presenter' do
        before do
         expect(CheesePresenter.configuration[:sort_orders][:canadianness]).not_to be_present
        end

        it 'returns false' do
          query_strat = described_class.new(options)
          expect(query_strat.send(:ordering?)).to eq(false)
        end
      end
    end

    context 'when the order param is not passed' do
      let(:params) { default_params }

      before do
        expect(params[:order]).not_to be_present
      end

      it 'returns false' do
        query_strat = described_class.new(options)
        expect(query_strat.send(:ordering?)).to eq(false)
      end
    end
  end
end
