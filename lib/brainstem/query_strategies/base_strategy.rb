module Brainstem
  module QueryStrategies
    class NotImplemented < StandardError
    end

    class BaseStrategy
      def initialize(options)
        @options = options
      end

      def execute(scope)
        raise NotImplemented, 'Your strategy class must implement an `execute` method'
      end

      def evaluate_scope(scope)
        # Load models!
        # On complex queries, MySQL can sometimes handle 'SELECT id FROM ... ORDER BY ...' much faster than
        # 'SELECT * FROM ...', so we pluck the ids, then find those specific ids in a separate query.
        if(ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql|sqlite/i)
          ids = scope.pluck("#{scope.table_name}.id")
          id_lookup = {}
          ids.each.with_index { |id, index| id_lookup[id] = index }
          primary_models = scope.klass.where(id: id_lookup.keys).sort_by { |model| id_lookup[model.id] }
        else
          primary_models = scope.to_a
        end
      end

      private

      def calculate_limit
        [[@options[:params][:limit].to_i, 1].max, (@options[:max_per_page] || @options[:default_max_per_page]).to_i].min
      end

      def calculate_offset
        [@options[:params][:offset].to_i, 0].max
      end

      def calculate_per_page
        per_page = [(@options[:params][:per_page] || @options[:per_page] || @options[:default_per_page]).to_i, (@options[:max_per_page] || @options[:default_max_per_page]).to_i].min
        per_page = @options[:default_per_page] if per_page < 1
        per_page
      end

      def calculate_page
        [(@options[:params][:page] || 1).to_i, 1].max
      end

      def filter_includes
        allowed_associations = @options[:primary_presenter].allowed_associations(@options[:params][:only].present?)

        [].tap do |selected_associations|
          (@options[:params][:include] || '').split(',').each do |k|
            if association = allowed_associations[k]
              selected_associations << association
            end
          end
        end
      end
    end
  end
end
