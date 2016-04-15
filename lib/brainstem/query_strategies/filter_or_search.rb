module Brainstem
  module QueryStrategies
    class FilterOrSearch < BaseStrategy
      def execute(scope)
        if searching?
          # Search
          sort_name, direction = @options[:primary_presenter].calculate_sort_name_and_direction @options[:params]
          scope, count, ordered_search_ids = run_search(scope, filter_includes.map(&:name), sort_name, direction)

          # Load models!
          primary_models = scope.to_a

          primary_models = order_for_search(primary_models, ordered_search_ids)
        else
          # Filter

          scope = @options[:primary_presenter].apply_filters_to_scope(scope, @options[:params], @options)

          if @options[:params][:only].present?
            # Handle Only
            scope, count = handle_only(scope, @options[:params][:only])
          else
            # Paginate
            scope, count = paginate scope
          end

          count = count.keys.length if count.is_a?(Hash)

          # Ordering
          scope = @options[:primary_presenter].apply_ordering_to_scope(scope, @options[:params])

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

        [primary_models, count]
      end

      private

      def searching?
        @options[:params][:search] && @options[:primary_presenter].configuration[:search].present?
      end

      def run_search(scope, includes, sort_name, direction)
        return scope unless searching?

        search_options = HashWithIndifferentAccess.new(
          include: includes,
          order: { sort_order: sort_name, direction: direction },
        )

        if @options[:params][:limit].present? && @options[:params][:offset].present?
          search_options[:limit] = calculate_limit
          search_options[:offset] = calculate_offset
        else
          search_options[:per_page] = calculate_per_page
          search_options[:page] = calculate_page
        end

        search_options.reverse_merge!(@options[:primary_presenter].extract_filters(@options[:params], @options))

        result_ids, count = @options[:primary_presenter].run_search(@options[:params][:search], search_options)
        if result_ids
          [scope.where(id: result_ids), count, result_ids]
        else
          raise(SearchUnavailableError, 'Search is currently unavailable')
        end
      end

      def paginate(scope)
        if @options[:params][:limit].present? && @options[:params][:offset].present?
          limit = calculate_limit
          offset = calculate_offset
        else
          limit = calculate_per_page
          offset = limit * (calculate_page - 1)
        end

        [scope.limit(limit).offset(offset).uniq, scope.select("distinct #{scope.connection.quote_table_name @options[:table_name]}.id").count]
      end

      def handle_only(scope, only)
        ids = (only || "").split(",").select {|id| id =~ /\A\d+\z/}.uniq
        [scope.where(:id => ids), scope.where(:id => ids).count]
      end

      def order_for_search(records, ordered_search_ids)
        ids_to_position = {}
        ordered_records = []

        ordered_search_ids.each_with_index do |id, index|
          ids_to_position[id] = index
        end

        records.each do |record|
          ordered_records[ids_to_position[record.id]] = record
        end

        ordered_records.compact
      end
    end
  end
end
