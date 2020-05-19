module Brainstem
  module QueryStrategies
    class NotImplemented < StandardError
    end

    class BaseStrategy
      def initialize(options)
        @options = options
        @last_count = nil
      end

      def execute(scope)
        raise NotImplemented, 'Your strategy class must implement an `execute` method'
      end

      def evaluate_scope(scope)
        @last_count = nil

        # Load models!
        # On complex queries, MySQL can sometimes handle 'SELECT id FROM ... ORDER BY ...' much faster than
        # 'SELECT * FROM ...', so we pluck the ids, then find those specific ids in a separate query.
        if ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql|sqlite/i
          get_ids_sql(scope)
        else
          scope.to_a
        end
      end

      def evaluate_count(count_scope)
        ret = @last_count || count_scope.count
        @last_count = nil
        ret
      end

      def calculate_per_page
        per_page = [(@options[:params][:per_page] || @options[:per_page] || @options[:default_per_page]).to_i, (@options[:max_per_page] || @options[:default_max_per_page]).to_i].min
        per_page = @options[:default_per_page] if per_page < 1
        per_page
      end

      private

      def get_ids_sql(scope)
        if Brainstem.mysql_use_calc_found_rows && ActiveRecord::Base.connection.instance_values["config"][:adapter] =~ /mysql/i
          ids = scope.pluck(Arel.sql("SQL_CALC_FOUND_ROWS #{scope.table_name}.id"))
          @last_count = ActiveRecord::Base.connection.execute("SELECT FOUND_ROWS()").first.first
        else
          ids = scope.pluck(Arel.sql("#{scope.table_name}.id"))
        end

        id_lookup = {}
        ids.each.with_index { |id, index| id_lookup[id] = index }
        scope.klass.where(id: id_lookup.keys).sort_by { |model| id_lookup[model.id] }
      end

      def calculate_limit
        [[@options[:params][:limit].to_i, 1].max, (@options[:max_per_page] || @options[:default_max_per_page]).to_i].min
      end

      def calculate_offset
        [@options[:params][:offset].to_i, 0].max
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

      def order_for_search(records, ordered_search_ids, options = {})
        ids_to_position = {}
        ordered_records = []

        ordered_search_ids.each_with_index do |id, index|
          ids_to_position[id] = index
        end

        records.each do |record|
          ordered_records[ids_to_position[options[:with_ids] ? record : record.id]] = record
        end

        ordered_records.compact
      end

      def calculate_limit_and_offset
        if @options[:params][:limit].present? && @options[:params][:offset].present?
          limit = calculate_limit
          offset = calculate_offset
        else
          limit = calculate_per_page
          offset = limit * (calculate_page - 1)
        end

        [limit, offset]
      end
    end
  end
end
