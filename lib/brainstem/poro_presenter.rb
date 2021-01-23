module Brainstem
  class PoroPresenter < Brainstem::Presenter
    def query_strategy(options)
      QueryStrategy.new
    end

    def prepare_context(models, association_objects_by_name, options)
      {
        fields: configuration[:fields]
      }
    end

    def preload(association_object_by_name, context, models)

    end

    def present_models(context, models, options)
      models.map do |model|
        result = present_fields(model, context, context[:fields])
        add_id(model, result)
        result
      end
    end

    def add_id(model, result)
      result['id'] = model.id
    end

    class QueryStrategy
      def execute(models)
        [models, 1]
      end

      def calculate_per_page
        1
      end
    end
  end
end
