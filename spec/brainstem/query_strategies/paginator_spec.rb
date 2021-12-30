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
    let(:primary_presenter) { WorkspacePresenter.new }
    let(:paginator) { described_class.new(primary_presenter: primary_presenter) }
    let(:scope) { Workspace.unscoped }
    let(:count_scope) { scope }
    let(:limit) { 0 }
    let(:offset) { 3 }

    describe '#get_ids' do
      context 'when using mysql_use_calc_found_rows' do
        before do
          Brainstem.mysql_use_calc_found_rows = true
          expect(Brainstem.mysql_use_calc_found_rows).to eq(true)
        end

        after do
          Brainstem.mysql_use_calc_found_rows = false
        end

        it 'issues SQL_CALC_FOUND_ROWS and SELECT FOUND_ROWS queries' do
          expect { paginator.get_ids(limit: limit, offset: offset, scope: scope) }.
            to make_database_queries({ count: 1, matching: /SELECT\s+DISTINCT SQL_CALC_FOUND_ROWS workspaces.id FROM/ }).
              and make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })
        end
      end

      context 'when not using mysql_use_calc_found_rows' do
        before do
          expect(Brainstem.mysql_use_calc_found_rows).to eq(false)
        end

        it 'does not issue any count queries' do
          expect { paginator.get_ids(limit: limit, offset: offset, scope: scope) }.not_to(
            make_database_queries(matching: "SELECT SQL_CALC_FOUND_ROWS workspaces.id FROM") &&
            make_database_queries(matching: "SELECT FOUND_ROWS()") &&
            make_database_queries(matching: /COUNT/)
          )
        end
      end
    end

    describe '#get_count' do
      context 'when primary presenter should evaluate count' do
        before do
          mock(primary_presenter).evaluate_count? { true }
        end

        it 'returns #evaluate_count from the primary presenter' do
          mock(primary_presenter).evaluate_count(count_scope) { 'fake count for testing' }

          expect(paginator.get_count(count_scope)).to eq 'fake count for testing'
        end
      end

      context 'when primary presenter should not evaluate count' do
        before do
          mock(primary_presenter).evaluate_count? { false }
        end

        it 'does not use #evaluate_count from the primary presenter' do
          mock(primary_presenter).evaluate_count(count_scope).never

          paginator.get_count(count_scope)
        end

        it 'uses scope to get count' do
          expect { paginator.get_count(count_scope) }.
            to make_database_queries({ count: 1, matching: "SELECT COUNT(*) FROM `workspaces`" })
        end

        context 'when using mysql_use_calc_found_rows' do
          before do
            Brainstem.mysql_use_calc_found_rows = true
            expect(Brainstem.mysql_use_calc_found_rows).to eq(true)
          end

          context 'when #get_ids has been run' do
            it 'does not query the database' do
              expect(paginator.get_ids(limit: limit, offset: offset, scope: scope)).to be

              expect { paginator.get_count(count_scope) }.to_not make_database_queries
            end
          end

          context 'when #get_ids has not been run' do
            it 'issues a count query to the database' do
              expect { paginator.get_count(count_scope) }.to make_database_queries(matching: "SELECT COUNT(*) FROM `workspaces`")
            end
          end
        end
      end
    end
  end
end
