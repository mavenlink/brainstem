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
            scope, count_scope = handle_only(scope, @options[:params][:only])
          else
            # Paginate
            scope, count_scope = paginate scope
          end

          # Ordering
          scope = @options[:primary_presenter].apply_ordering_to_scope(scope, @options[:params])

          primary_models = evaluate_scope(scope)
          count = detected_count || count_scope.count
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
        limit, offset = calculate_limit_and_offset
        [scope.limit(limit).offset(offset).distinct, scope.select("distinct #{scope.connection.quote_table_name @options[:table_name]}.id")]
      end

      def handle_only(scope, only)
        ids = (only || "").split(",").select {|id| id =~ /\A\d+\z/}.uniq
        [scope.where(:id => ids), scope.where(:id => ids)]
      end
    end
  end
end
