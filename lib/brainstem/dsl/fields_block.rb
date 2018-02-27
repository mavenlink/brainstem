module Brainstem
  module Concerns
    module PresenterDSL
      class FieldsBlock < BaseBlock
        def field(name, type, options = {})
          configuration[name] = DSL::Field.new(name, type, smart_merge(block_options, format_options(options)))
        end

        def fields(name, type = :hash, options = {}, &block)
          if type == :array
            nested_field = DSL::NestedArrayField.new(name, type, smart_merge(block_options, format_options(options)))
            configuration[name] = nested_field

            descend self.class, nested_field.configuration, merge_parent_options(block_options, options), &block
          else
            descend FieldsBlock, configuration.nest!(name), &block
          end
        end

        private

        NON_INHERITABLE_FIELD_OPTIONS = [:dynamic, :via, :lookup, :lookup_fetch, :info, :type, :item_type]
        private_constant :NON_INHERITABLE_FIELD_OPTIONS

        def merge_parent_options(block_options, parent_options)
          inheritable_options = parent_options.except(*NON_INHERITABLE_FIELD_OPTIONS)
          inheritable_options[:use_parent_value] = true unless inheritable_options.has_key?(:use_parent_value)

          block_options.deep_dup.merge(inheritable_options)
        end

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
