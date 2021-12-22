require "spec_helper"

describe Brainstem::QueryStrategies::Paginator do
  using_mysql = ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql/i
  if using_mysql
    xit '- Tests requiring sqlite have not been run.' do
      expect(true).to eq false
    end
  else
    xit '- Tests requiring mysql have not been run.' do
      expect(true).to eq false
    end
  end

  if using_mysql
    let(:paginator) { described_class.new(primary_presenter: WorkspacePresenter.new) }

    describe '#paginate' do
      let(:scope) { Workspace.unscoped }
      let(:count_scope) { scope }
      let(:page) { 1 }

      context 'when using mysql_use_calc_found_rows' do
        before do
          Brainstem.mysql_use_calc_found_rows = true
          expect(Brainstem.mysql_use_calc_found_rows).to eq(true)
        end

        after do
          Brainstem.mysql_use_calc_found_rows = false
        end

        it 'issues SQL_CALC_FOUND_ROWS and SELECT FOUND_ROWS queries' do
          expect { paginator.paginate(page: page, scope: scope, count_scope: count_scope) }.
            to make_database_queries({ count: 1, matching: "SELECT SQL_CALC_FOUND_ROWS workspaces.id FROM" }).
              and make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })
        end
      end

      context 'when not using mysql_use_calc_found_rows' do
        before do
          expect(Brainstem.mysql_use_calc_found_rows).to eq(false)
        end

        it 'returns the results by issuing a count query' do
          expect { paginator.paginate(page: page, scope: scope, count_scope: count_scope) }.
            not_to make_database_queries({ count: 1, matching: "SELECT SQL_CALC_FOUND_ROWS workspaces.id FROM" })
          expect { paginator.paginate(page: page, scope: scope, count_scope: count_scope) }.
            not_to make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })

          expect { paginator.paginate(page: page, scope: scope, count_scope: count_scope) }.
            to make_database_queries({ count: 1, matching: "SELECT COUNT(*) FROM" })
        end
      end
    end
  end
end
