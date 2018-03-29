module Brainstem
  module Concerns
    module PresenterDSL
      class FieldsBlock < BaseBlock
        def field(name, type, options = {})
          configuration[name] = DSL::Field.new(name, type, smart_merge(block_options, format_options(options)))
        end

        def fields(name, &block)
          descend FieldsBlock, configuration.nest!(name), &block
        end

        private

        def smart_merge(block_options, options)
          if_clause = ([block_options[:if]] + [options[:if]]).flatten(2).compact.uniq
          block_options.merge(options).tap do |opts|
            opts.merge!(if: if_clause) if if_clause.present?
          end
        end

        def format_options(options)
          options[:item_type] = options[:item_type].to_s if options.has_key?(:item_type)
          super
        end
      end
    end
  end
end
