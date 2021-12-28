module Brainstem
  module QueryStrategies
    class DataMapper
      def get_models(ids:, scope:)
        id_lookup = {}
        ids.each.with_index { |id, index| id_lookup[id] = index }
        scope.klass.where(id: ids).sort_by { |model| id_lookup[model.id] }
      end
    end
  end
end
