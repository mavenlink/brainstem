module Brainstem
  module QueryStrategies
    class DataMapper
      def get_models(ids:, scope:)
        models = _get_models(scope, ids)
        sort_models(models, ids)
      end

      private

      def _get_models(scope, ids)
        scope.klass.where(id: ids)
      end

      def sort_models(models, ids)
        model_order = {}
        ids.each.with_index { |id, index| model_order[id] = index }
        models.sort_by { |model| model_order[model.id] }
      end
    end
  end
end
