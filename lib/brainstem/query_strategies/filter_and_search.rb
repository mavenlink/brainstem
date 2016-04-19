module Brainstem
  module QueryStrategies
    class FilterAndSearch < BaseStrategy
      def execute(scope)
        ordered_search_ids = run_search(scope, filter_includes.map(&:name))
        scope = scope.where(id: ordered_search_ids)
        scope = @options[:primary_presenter].apply_filters_to_scope(scope, @options[:params], @options)
        scope = @options[:primary_presenter].apply_ordering_to_scope(scope, @options[:params])
        count = scope.count
        scope = paginate(scope)

        [scope, count]
      end

      private

      def run_search(scope, includes)
        sort_name, direction = @options[:primary_presenter].calculate_sort_name_and_direction @options[:params]
        search_options = HashWithIndifferentAccess.new(
          include: includes,
          order: { sort_order: sort_name, direction: direction },
          limit: @options[:default_max_filter_and_search_page],
          offset: 0
        )

        search_options.reverse_merge!(@options[:primary_presenter].extract_filters(@options[:params], @options))

        result_ids, _ = @options[:primary_presenter].run_search(@options[:params][:search], search_options)
        if result_ids
          result_ids
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

        scope.limit(limit).offset(offset).uniq
      end
    end
  end
end
