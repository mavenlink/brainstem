require 'spec_helper'

# The functionality of this is mainly tested in more integration-y tests in presenter_collection_spec.rb

describe Brainstem::PaginationStrategies::FilterOrSearch do
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
        expect(subject.execute(Workspace.all)).to eq([@results, 2])
      end
    end

    context 'we are not searching' do
      let(:subject) { described_class.new(@options) }

      before do
        @options = { primary_presenter: WorkspacePresenter.new,
                     table_name: 'workspaces',
                     default_per_page: 20,
                     default_max_per_page: 200,
                     params: { } }
      end

      it 'returns the primary models and count' do
        expect(subject.execute(Workspace.all)).to eq([Workspace.all.to_a, Workspace.count])
      end
    end
  end
end
