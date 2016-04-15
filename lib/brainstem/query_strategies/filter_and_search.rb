module Brainstem
  module QueryStrategies
    class FilterAndSearch
      def initialize(options)
        @options = options
      end

      def execute(scope)
        scope = @options[:primary_presenter].apply_filters_to_scope(scope, @options[:params], @options)
        original_scope = scope

        scope_ids = scope.select(:id).pluck(:id)

        ordered_search_ids = run_search(scope, filter_includes.map(&:name))

        intersection_of_search_and_filter = scope_ids & ordered_search_ids

        scope = original_scope.where(id: intersection_of_search_and_filter)
        scope = paginate(scope)
        [scope, intersection_of_search_and_filter.length]
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
