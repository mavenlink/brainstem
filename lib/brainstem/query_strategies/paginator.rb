module Brainstem
  module QueryStrategies
    class Paginator
      attr_reader :pagination_strategy, :primary_presenter

      def initialize(primary_presenter:)
        @primary_presenter = primary_presenter
        @last_count = nil
      end

      def get_ids_for_paginated_scope(scope)
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

      def get_ids(limit:, offset:, scope:)
        paginated_scope = scope.limit(limit).offset(offset).distinct
        get_ids_for_paginated_scope(paginated_scope)
      end

      def get_count(scope)
        return primary_presenter.evaluate_count(scope) if delegate_count_to_presenter?
        binding.pry
        ret = @last_count || scope.reorder(nil).count
        @last_count = nil
        ret
      end

      def delegate_count_to_presenter?
        !!primary_presenter&.evaluate_count?
      end
    end
  end
end
