require "spec_helper"

shared_examples_for Brainstem::QueryStrategies::BaseStrategy do
  let(:strategy) { described_class.new(options) }
  using_mysql = ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql/i
  if using_mysql
    describe 'mysql_use_calc_found_rows' do
      let(:options) { { params: { page: 1 } } }

      context 'when using mysql_use_calc_found_rows' do
        before do
          Brainstem.mysql_use_calc_found_rows = true
          expect(Brainstem.mysql_use_calc_found_rows).to eq(true)
        end

        after do
          Brainstem.mysql_use_calc_found_rows = false
        end

        it 'returns the results without issuing a second query' do
          expect { strategy.evaluate_scopes(Workspace.unscoped, Workspace.unscoped) }.
            to make_database_queries({ count: 1, matching: "SELECT SQL_CALC_FOUND_ROWS workspaces.id FROM" }).
            and make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })
        end
      end

      context 'when not using mysql_use_calc_found_rows' do
        before do
          expect(Brainstem.mysql_use_calc_found_rows).to eq(false)
        end

        it 'returns the results by issuing a count query' do
          expect { strategy.evaluate_scopes(Workspace.unscoped, Workspace.unscoped) }.
            not_to make_database_queries({ count: 1, matching: "SELECT SQL_CALC_FOUND_ROWS workspaces.id FROM" })
          expect { strategy.evaluate_scopes(Workspace.unscoped, Workspace.unscoped) }.
            not_to make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })

          expect { strategy.evaluate_count(Workspace.unscoped) }.
            to make_database_queries({ count: 1, matching: "SELECT COUNT(*) FROM" })
        end
      end
    end
  end

  describe 'custom pagination' do
    context 'when options contain a paginator' do
      let(:page) { 1 }
      let(:fake_get_paged_results) { [[8, 5], 999] }
      let(:options) do
        {
          paginator: paginator,
          primary_presenter: CheesePresenter.new,
          params: {
            page: page,
            per_page: 10,
          },
          default_per_page: 20,
          default_max_per_page: 200,
          max_per_page: 100
        }
      end

      if using_mysql
        xit '- Tests requiring sqlite have not been run.' do
          expect(true).to eq false
        end

        context 'when using mysql' do
          let(:paginator) do
            paginator = Object.new
            mock(paginator).get_paged(page, anything) { fake_get_paged_results }
            paginator
          end

          before { Brainstem.mysql_use_calc_found_rows = true }
          after { Brainstem.mysql_use_calc_found_rows = false }

          it 'uses the mocked paginator and only queries the database once' do
            expect { strategy.evaluate_scopes(Workspace.unscoped, Workspace.unscoped).to_a }.
              to make_database_queries(count: 1)
          end

          context 'when custom paginator fails' do
            let(:fake_get_paged_results) { [nil, nil] }

            it 'uses mysql SQL_CALC_FOUND_ROWS and FOUND_ROWS' do
              expect { strategy.evaluate_scopes(Workspace.unscoped, Workspace.unscoped).to_a }.
                to make_database_queries({ count: 1, matching: "SELECT SQL_CALC_FOUND_ROWS" }).
                  and make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })
            end
          end
        end
      else
        xit '- Tests requiring mysql have not been run.' do
          expect(true).to eq false
        end

        context 'when not using mysql' do
          context 'the paginator is not used' do
            let(:paginator) do
              paginator = Object.new
              mock(paginator).get_paged(anything, anything).never
              paginator
            end

            it 'uses scope to get page data' do
              expect { strategy.evaluate_scopes(Workspace.unscoped, Workspace.unscoped).to_a }.
                to make_database_queries(count: 1, matching: 'SELECT workspaces.id FROM "workspaces"').
                  and make_database_queries(
                    count: 1,
                    matching: 'SELECT "workspaces".* FROM "workspaces" WHERE "workspaces"."id" IN ('
                  )
            end
          end
        end
      end
    end
  end

  describe "#calculate_per_page" do
    let(:result) { strategy.calculate_per_page }

    [
      # per_page  default_per_page  max_per_page  default_max_per_page  expected   situation                             used
      [       10,               20,          100,                  200,       10,  "per page < max",                     "the per page"],
      [      nil,               20,          100,                  200,       20,  "no per page and default < max",      "the default"],
      [      nil,              200,          100,                  200,      100,  "no per page and default > max",      "the max"],
      [      150,               20,          100,                  200,      100,  "per page > max",                     "the max"],
      [      150,               20,          nil,                  200,      150,  "no max and per page < default max",  "the per page"],
      [      250,               20,          nil,                  200,      200,  "no max and per page > default max",  "the default max"],
    ].each do |per_page, default_per_page, max_per_page, default_max_per_page, expected, situation, used|
      describe "when #{situation}" do
        let(:options) {
          {
            params: {
              per_page: per_page,
            },
            default_per_page: default_per_page,
            default_max_per_page: default_max_per_page,
            max_per_page: max_per_page,
          }
        }

        it "uses #{used}" do
          expect(result).to eq(expected)
        end
      end
    end
  end
end
