module Brainstem
  module QueryStrategies
    class Paginator
      attr_reader :pagination_strategy, :primary_presenter

      def initialize(primary_presenter:)
        @primary_presenter = primary_presenter
        @cached_count = nil
      end

      def get_ids(scope:, limit:, offset:)
        scope = scope.limit(limit) if limit.present?
        scope = scope.offset(offset) if offset.present?
        scope = scope.distinct

        if use_mysql_calc_row?
          get_ids_and_cache_count(scope)
        else
          scope.pluck(Arel.sql("#{scope.table_name}.id"))
        end
      end

      def get_count(scope)
        return primary_presenter.evaluate_count(scope) if delegate_count_to_presenter?
        return @cached_count unless @cached_count.nil?

        # `relation.count` returns a hash if the relation is grouped.
        count = scope.offset(nil).limit(nil).count
        count = count.keys.length if count.is_a?(Hash)

        @cached_count = count
        count
      end

      private

      def get_ids_and_cache_count(scope)
        ids = scope.pluck(Arel.sql("SQL_CALC_FOUND_ROWS #{scope.table_name}.id"))
        @cached_count = ActiveRecord::Base.connection.execute("SELECT FOUND_ROWS()").first.first

        ids
      end

      def use_mysql_calc_row?
        return false unless Brainstem.mysql_use_calc_found_rows
        return false unless ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql/i

        true
      end

      def delegate_count_to_presenter?
        !!primary_presenter&.evaluate_count?
      end
    end
  end
end
