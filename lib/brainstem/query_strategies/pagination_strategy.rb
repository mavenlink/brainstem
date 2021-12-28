module Brainstem
  module QueryStrategies
    class PaginationStrategy
      def initialize
        @last_count = nil
      end

      def get_models_for_page(scope:, page: nil, per_page: nil)
        @last_count = nil

        # On complex queries, MySQL can sometimes handle 'SELECT id FROM ... ORDER BY ...' much faster than
        # 'SELECT * FROM ...', so we pluck the ids, then find those specific ids in a separate query.
        if ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql|sqlite/i
          get_models_using_ids(scope: scope)
        else
          scope.to_a
        end
      end

      def get_count(count_scope)
        ret = @last_count || count_scope.reorder(nil).count
        @last_count = nil
        ret
      end

      private

      def get_models_using_ids(scope:, page: nil, per_page: nil)
        ids = get_ids_for_page(scope: scope, page: page, per_page: per_page)
        id_lookup = {}
        ids.each.with_index { |id, index| id_lookup[id] = index }
        scope.klass.where(id: id_lookup.keys).sort_by { |model| id_lookup[model.id] }
      end

      def get_ids_for_page(scope:, page: nil, per_page: nil)
        if use_calc_row?
          ids = scope.pluck(Arel.sql("SQL_CALC_FOUND_ROWS #{scope.table_name}.id"))
          @last_count = ActiveRecord::Base.connection.execute("SELECT FOUND_ROWS()").first.first
        else
          ids = scope.pluck(Arel.sql("#{scope.table_name}.id"))
        end

        ids
      end

      def use_calc_row?
        return false unless Brainstem.mysql_use_calc_found_rows
        return false unless ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql/i

        true
      end
    end
  end
end
