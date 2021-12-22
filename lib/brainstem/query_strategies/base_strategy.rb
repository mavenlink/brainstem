module Brainstem
  module QueryStrategies
    class NotImplemented < StandardError
    end

    class BaseStrategy
      def initialize(options)
        @options = options
      end

      def execute(scope)
        raise NotImplemented, 'Your strategy class must implement an `execute` method'
      end

      def calculate_per_page
        per_page = [
          (@options[:params][:per_page] || @options[:per_page] || @options[:default_per_page]).to_i,
          (@options[:max_per_page] || @options[:default_max_per_page]).to_i
        ].min
        per_page = @options[:default_per_page] if per_page < 1
        per_page
      end

      private

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
        allowed_associations = primary_presenter.allowed_associations(@options[:params][:only].present?)

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

      def primary_presenter
        @options[:primary_presenter]
      end

      def paginator
        @options[:paginator] || QueryStrategies::Paginator.new(primary_presenter: primary_presenter)
      end
    end
  end
end
