module Brainstem
  module QueryStrategies
    class FilterAndSearch < BaseStrategy
      def execute(scope)
        scope, ordered_search_ids = run_search(scope, filter_includes.map(&:name))
        scope = @options[:primary_presenter].apply_filters_to_scope(scope, @options[:params], @options)

        if ordering?
          count_scope = scope
          scope = @options[:primary_presenter].apply_ordering_to_scope(scope, @options[:params])
          limit, offset = calculate_limit_and_offset
          ids = paginator.get_ids(limit: limit, offset: offset, scope: scope)
          count = paginator.get_count(scope)
          primary_models = Brainstem::QueryStrategies::DataMapper.new.get_models(ids: ids, scope: scope)
        else
          filtered_ids = scope.pluck(:id)
          count = filtered_ids.size

          # order a potentially large set of ids
          ordered_ids = order_for_search(filtered_ids, ordered_search_ids, with_ids: true)
          ordered_paginated_ids = paginate_array(ordered_ids)

          scope = scope.unscoped.where(id: ordered_paginated_ids)
          # not using `evaluate_scope` because we are already instantiating
          # a scope based on ids
          primary_models = scope.to_a

          # Once hydrated, a page worth of models needs to be reordered
          # due to the `scope.unscoped.where(id: ...` clobbering our ordering
          primary_models = order_for_search(primary_models, ordered_paginated_ids)
        end

        [primary_models, count]
      end

      private

      def run_search(scope, includes)
        search_options = ActiveSupport::HashWithIndifferentAccess.new(
          include: includes,
          limit: @options[:default_max_filter_and_search_page],
          offset: 0
        )

        search_options.reverse_merge!(@options[:primary_presenter].extract_filters(@options[:params], @options))

        result_ids, _ = @options[:primary_presenter].run_search(@options[:params][:search], search_options)
        if result_ids
          resulting_scope = scope.where(id: result_ids)
          [resulting_scope, result_ids]
        else
          raise(SearchUnavailableError, 'Search is currently unavailable')
        end
      end

      def ordering?
        sort_name = @options[:params][:order].to_s.split(":").first
        sort_orders = @options[:primary_presenter].configuration[:sort_orders]
        sort_name.present? && sort_orders && sort_orders[sort_name].present?
      end

      def paginated_scope(scope)
        limit, offset = calculate_limit_and_offset
        scope.limit(limit).offset(offset).distinct
      end

      def paginate_array(array)
        limit, offset = calculate_limit_and_offset
        array.drop(offset).first(limit) # do we need to uniq this?
      end
    end
  end
end
