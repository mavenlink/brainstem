module Brainstem
  module QueryStrategies
    class FilterAndSearch < BaseStrategy
      def execute(scope)
        scope, ordered_search_ids = run_search(scope, filter_includes.map(&:name))
        scope = @options[:primary_presenter].apply_filters_to_scope(scope, @options[:params], @options)
        count = scope.count

        if ordering?
          scope = paginate(scope)
          scope = @options[:primary_presenter].apply_ordering_to_scope(scope, @options[:params])
          primary_models = evaluate_scope(scope)
        else
          primary_models = scope.to_a
          primary_models = order_for_search(primary_models, ordered_search_ids)
          primary_models = paginate_array(primary_models)
        end

        [primary_models, count]
      end

      private

      def run_search(scope, includes)
        search_options = HashWithIndifferentAccess.new(
          include: includes,
          limit: @options[:default_max_filter_and_search_page],
          offset: 0
        )

        search_options.reverse_merge!(@options[:primary_presenter].extract_filters(@options[:params], @options))

        result_ids, _ = @options[:primary_presenter].run_search(@options[:params][:search], search_options)
        if result_ids
          [scope.where(id: result_ids), result_ids]
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

        scope.limit(limit).offset(offset).distinct
      end

      def ordering?
        @options[:params][:order].present?
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

      def paginate_array(array)
        if @options[:params][:limit].present? && @options[:params][:offset].present?
          limit = calculate_limit
          offset = calculate_offset
        else
          limit = calculate_per_page
          offset = limit * (calculate_page - 1)
        end

        array.drop(offset).first(limit) # do we need to uniq this?
      end
    end
  end
end
