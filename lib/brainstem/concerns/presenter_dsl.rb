require 'brainstem/concerns/inheritable_configuration'
require 'brainstem/dsl/association'
require 'brainstem/dsl/field'
require 'brainstem/dsl/conditional'

module Brainstem
  module Concerns
    module PresenterDSL
      extend ActiveSupport::Concern
      include Brainstem::Concerns::InheritableConfiguration

      included do
        configuration.array!(:preloads)
        configuration.array!(:helpers)
        configuration.nest!(:conditionals)
        configuration.nest!(:fields)
        configuration.nest!(:associations)
      end

      class BaseBlock
        attr_accessor :configuration, :block_options

        def initialize(configuration, block_options = {}, &block)
          @configuration = configuration
          @block_options = block_options
          block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
        end

        def with_options(new_options = {}, &block)
          descend self.class, configuration, new_options, &block
        end

        protected

        def descend(klass, new_config = configuration, new_options = {}, &block)
          klass.new(new_config, block_options.merge(new_options), &block)
        end

        def parse_args(args)
          options = args.last.is_a?(Hash) ? args.pop : {}
          description = args.shift
          [description, options]
        end
      end

      class ConditionalsBlock < BaseBlock
        def request(name, action, description = nil)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :request, action, description)
        end

        def model(name, action, description = nil)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :model, action, description)
        end
      end

      class FieldsBlock < BaseBlock
        def field(name, type, *args)
          description, options = parse_args(args)
          configuration[name] = DSL::Field.new(name, type, description, block_options.merge(options))
        end

        def fields(name, &block)
          descend FieldsBlock, configuration.nest!(name), &block
        end
      end

      class AssociationsBlock < BaseBlock
        def association(name, target_class, *args)
          description, options = parse_args(args)
          configuration[:associations][name] = DSL::Association.new(name, target_class, description, block_options.merge(options))
        end
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

        # Declare a helper module or block whose methods will be available in dynamic fields and associations.
        # TODO: make available inside sort and filter blocks
        def helper(mod = nil, &block)
          if mod
            configuration[:helpers] << mod
          end

          if block
            configuration[:helpers] << Module.new.tap { |mod| mod.module_eval(&block) }
          end
        end
      end
    end
  end
end
