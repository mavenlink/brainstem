require 'spec_helper'

# The functionality of this is mainly tested in more integration-y tests in presenter_collection_spec.rb

describe Brainstem::QueryStrategies::FilterOrSearch do
  it_behaves_like Brainstem::QueryStrategies::BaseStrategy

  describe '#execute' do
    context 'we are searching' do
      let(:subject) { described_class.new(@options) }

      before do
        @options = { primary_presenter: WorkspacePresenter.new,
                     table_name: 'workspaces',
                     default_per_page: 20,
                     default_max_per_page: 200,
                     params: { search: "cheese" } }

        @results = [Workspace.first, Workspace.second]

        WorkspacePresenter.search do |string|
          [[1,2], 2]
        end
      end

      it 'returns the primary models and count' do
        expect(subject.execute(Workspace.unscoped)).to eq([@results, 2])
      end
    end

    context 'we are not searching' do
      let(:options) do
        {
          primary_presenter: WorkspacePresenter.new,
          table_name: 'workspaces',
          default_per_page: 20,
          default_max_per_page: 200,
          params: {}
        }
      end
      let(:subject) { described_class.new(options) }

      it 'returns the primary models and count' do
        expect(subject.execute(Workspace.unscoped)).to eq([Workspace.unscoped.to_a, Workspace.count])
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
              expect { subject.execute(Workspace.unscoped) }.
                not_to make_database_queries({ count: 1, matching: "SELECT COUNT(*) FROM" })

              expect { subject.execute(Workspace.unscoped) }.
                to make_database_queries({ count: 1, matching: "SELECT  DISTINCT SQL_CALC_FOUND_ROWS workspaces.id FROM" }).
                and make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })

              _, count = subject.execute(Workspace.unscoped)
              expect(count).to eq(Workspace.count)
            end
          end

          context 'when not using mysql_use_calc_found_rows' do
            before do
              expect(Brainstem.mysql_use_calc_found_rows).to eq(false)
            end

            it 'returns the results by issuing a count query' do
              expect { subject.execute(Workspace.unscoped) }.
                to make_database_queries({ count: 1, matching: "SELECT COUNT(distinct `workspaces`.id) FROM" })

              expect { subject.execute(Workspace.unscoped) }.
                not_to make_database_queries({ count: 1, matching: "SELECT  DISTINCT SQL_CALC_FOUND_ROWS workspaces.id FROM" })

              expect { subject.execute(Workspace.unscoped) }.
                not_to make_database_queries({ count: 1, matching: "SELECT FOUND_ROWS()" })
            end
          end
        end
      end
    end
  end
end
