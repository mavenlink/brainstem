module Brainstem
  module QueryStrategies
    class Paginator
      attr_reader :pagination_strategy, :primary_presenter

      def initialize(primary_presenter:, pagination_strategy:)
        @primary_presenter = primary_presenter
        @pagination_strategy = pagination_strategy
      end

      def paginate(page:, per_page:, scope:, count_scope:)
        models = pagination_strategy.get_models_for_page(scope: scope, page: page, per_page: per_page)
        count = get_count(count_scope)
        count = count.keys.length if count.is_a?(Hash)
        [models, count]
      end

      def get_count(count_scope)
        return primary_presenter.evaluate_count(count_scope) if delegate_count_to_presenter?
        pagination_strategy.get_count(count_scope)
      end

      def delegate_count_to_presenter?
        !!primary_presenter&.evaluate_count?
      end
    end
  end
end
