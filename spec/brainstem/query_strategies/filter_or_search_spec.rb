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
      let(:default_options) do
        {
          primary_presenter: WorkspacePresenter.new,
          table_name: 'workspaces',
          default_per_page: 20,
          default_max_per_page: 200,
          params: {}
        }
      end
      let(:options) { default_options }
      let(:subject) { described_class.new(options) }

      it 'returns the primary models and count' do
        expect(subject.execute(Workspace.unscoped)).to eq([Workspace.unscoped.to_a, Workspace.count])
      end

      context 'when options contain a paginator' do
        let(:paginator) { Object.new }
        let(:options) { default_options.merge(paginator: paginator) }

        it 'uses the provided paginator' do
          mock(paginator).get_ids(anything) { [] }
          mock(paginator).get_count(anything)
          subject.execute(Workspace.unscoped)
        end
      end
    end
  end
end
