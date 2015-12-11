require 'brainstem/concerns/inheritable_configuration'
require 'brainstem/dsl/association'
require 'brainstem/dsl/field'
require 'brainstem/dsl/conditional'

require 'brainstem/dsl/base_block'
require 'brainstem/dsl/conditionals_block'
require 'brainstem/dsl/fields_block'
require 'brainstem/dsl/associations_block'


require 'active_support/core_ext/array/extract_options'

module Brainstem
  module Concerns
    module PresenterDSL
      extend ActiveSupport::Concern
      include Brainstem::Concerns::InheritableConfiguration

      included do
        reset_configuration!
      end

      module ClassMethods
        def preload(*args)
          configuration.array!(:preloads).concat args
        end

        def conditionals(&block)
          ConditionalsBlock.new(configuration, &block)
        end

        def fields(&block)
          FieldsBlock.new(configuration[:fields], &block)
        end

        def associations(&block)
          AssociationsBlock.new(configuration, &block)
        end

        def title(str, options = { nodoc: false })
          configuration[:title] = options.merge(info: str)
        end

        def description(str, options = { nodoc: false })
          configuration[:description] = options.merge(info: str)
        end

        def nodoc!
          configuration[:nodoc] = true
        end

        # Declare a helper module or block whose methods will be available in dynamic fields and associations.
        def helper(mod = nil, &block)
          if mod
            configuration[:helpers] << mod
          end

          if block
            configuration[:helpers] << Module.new.tap { |mod| mod.module_eval(&block) }
          end
        end


        # @overload default_sort_order(sort_string)
        #   Sets a default sort order.
        #   @param [String] sort_string The sort order to apply by default
        #     while presenting. The string must contain the name of a sort order
        #     that has explicitly been declared using {sort_order}. The string
        #     may end in +:asc+ or +:desc+ to indicate the default order's
        #     direction.
        #   @return [String] The new default sort order.
        # @overload default_sort_order
        #   @return [String] The default sort order, or nil if one is not set.
        def default_sort_order(sort_string = nil)
          configuration[:default_sort_order] = sort_string if sort_string
          configuration[:default_sort_order]
        end


        #
        # @overload sort_order(name, order, options)
        #   @param [Symbol] name The name of the sort order.
        #   @param [String] order The SQL string to use to sort the presented
        #     data.
        #   @param [Hash] options
        #   @option options [String] :info Docstring for the sort order
        #   @option options [Boolean] :nodoc Whether this sort order be
        #     included in the generated documentation
        #
        # @overload sort_order(name, options, &block)
        #   @yieldparam scope [ActiveRecord::Relation] The scope representing
        #     the data being presented.
        #   @yieldreturn [ActiveRecord::Relation] A new scope that adds
        #     ordering requirements to the scope that was yielded.
        #
        #   Create a named sort order, either containing a string to use as
        #   ORDER in a query, or with a block that adds an order Arel predicate
        #   to a scope.
        #
        # @raise [ArgumentError] if neither an order string or block is given.
        #
        def sort_order(name, *args, &block)
          valid_options = %w(info nodoc)
          options       = args.extract_options!
                            .select { |k, v| valid_options.include?(k.to_s) }
          order         = args.first

          raise ArgumentError, "A sort order must be given" unless block_given? || order
          configuration[:sort_orders][name] = options.merge({
            value: (block_given? ? block : order)
          })
        end


        #
        # @overload filter(name, options = {})
        #   @param [Symbol] name The name of the scope that may be applied as a
        #     filter.
        #   @option options [Object] :default If set, causes this filter to be
        #     applied to every request. If the filter accepts parameters, the
        #     value given here will be passed to the filter when it is applied.
        #   @option options [String] :info Docstring for the filter.
        #
        # @overload filter(name, options = {}, &block)
        #   @param [Symbol] name The filter can be requested using this name.
        #   @yieldparam scope [ActiveRecord::Relation] The scope that the
        #     filter should use as a base.
        #   @yieldparam arg [Object] The argument passed when the filter was
        #     requested.
        #   @yieldreturn [ActiveRecord::Relation] A new scope that filters the
        #     scope that was yielded.
        #
        def filter(name, options = {}, &block)
          valid_options = %w(default info include_params nodoc)
          options.select! { |k, v| valid_options.include?(k.to_s) }

          configuration[:filters][name] = options.merge({
            value: (block_given? ? block : nil)
          })
        end


        def search(&block)
          configuration[:search] = block
        end

        def brainstem_key(key)
          configuration[:brainstem_key] = key.to_s
        end

        # @api private
        def reset_configuration!
          configuration.array!(:preloads)
          configuration.array!(:helpers)
          configuration.nest!(:conditionals)
          configuration.nest!(:fields)
          configuration.nest!(:filters)
          configuration.nest!(:sort_orders)
          configuration.nest!(:associations)
          configuration.nonheritable!(:title)
          configuration.nonheritable!(:description)
          configuration.nonheritable!(:nodoc)
        end
      end
    end
  end
end
