require "spec_helper"

shared_examples_for Brainstem::QueryStrategies::BaseStrategy do
  let(:strategy) { described_class.new(options) }

  if(ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql/i)
    describe 'mysql_use_calc_found_rows' do
      let(:options) {{}}

      context 'when using mysql_use_calc_found_rows' do
        before do
          Brainstem.mysql_use_calc_found_rows = true
          expect(Brainstem.mysql_use_calc_found_rows).to eq(true)
        end

        after do
          Brainstem.mysql_use_calc_found_rows = false
        end

        it 'returns the results without issuing a second query' do
          expect { strategy.evaluate_scope(Workspace.unscoped) }.
            to make_database_queries({ count: 1, matching: "SELECT SQL_CALC_FOUND_ROWS workspaces.id FROM" }).
            and make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })

          count_scope_that_should_not_be_used = Workspace.none
          count_expected = Workspace.count

          expect {
            expect(strategy.evaluate_count(count_scope_that_should_not_be_used)).to eq(count_expected)
          }.not_to make_database_queries
        end
      end

      context 'when not using mysql_use_calc_found_rows' do
        before do
          expect(Brainstem.mysql_use_calc_found_rows).to eq(false)
        end

        it 'returns the results by issuing a count query' do
          expect { strategy.evaluate_scope(Workspace.unscoped) }.
            not_to make_database_queries({ count: 1, matching: "SELECT SQL_CALC_FOUND_ROWS workspaces.id FROM" })
          expect { strategy.evaluate_scope(Workspace.unscoped) }.
            not_to make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })

          expect { strategy.evaluate_count(Workspace.unscoped) }.
            to make_database_queries({ count: 1, matching: "SELECT COUNT(*) FROM" })
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
