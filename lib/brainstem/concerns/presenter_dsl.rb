require 'brainstem/concerns/inheritable_configuration'

module Brainstem
  module Concerns
    module PresenterDSL
      extend ActiveSupport::Concern
      include Brainstem::Concerns::InheritableConfiguration

      class BaseBlock
        attr_accessor :configuration, :block_options

        def initialize(configuration, block_options = {}, &block)
          @configuration = configuration
          @block_options = block_options
          setup_defaults!
          block.arity < 1 ? self.instance_eval(&block) : block.call(self) if block_given?
        end

        def with_options(new_options = {}, &block)
          descend self.class, new_options, &block
        end

        protected

        def descend(klass, new_options = {}, &block)
          klass.new(configuration, block_options.merge(new_options), &block)
        end

        def setup_defaults!
        end

        def parse_args(args)
          options = args.last.is_a?(Hash) ? args.pop : {}
          description = args.shift
          [description, options]
        end
      end

      class PresenterBlock < BaseBlock
        def preload(*args)
          configuration.array!(:preloads).concat args
        end

        def conditionals(&block)
          descend ConditionalsBlock, &block
        end

        def fields(&block)
          descend FieldsBlock, &block
        end

        def associations(&block)
          descend AssociationsBlock, &block
        end

        protected

        def setup_defaults!
          super
          configuration.array!(:preloads)
          configuration.nest!(:conditionals)
          configuration.nest!(:fields)
          configuration.nest!(:associations)
        end
      end

      class ConditionalsBlock < BaseBlock
        def collection(name, action, description = nil)
          configuration[:conditionals][name] = { type: :collection, action: action, description: description }
        end

        def model(name, action, description = nil)
          configuration[:conditionals][name] = { type: :model, action: action, description: description }
        end
      end

      class FieldsBlock < BaseBlock
        def field(name, type, *args)
          description, options = parse_args(args)
          configuration[:fields][name] = { type: type, description: description, options: block_options.merge(options) }
        end
      end

      class AssociationsBlock < BaseBlock
        def association(name, klass, *args)
          description, options = parse_args(args)
          configuration[:associations][name] = { class: klass, description: description, options: block_options.merge(options) }
        end
      end

      module ClassMethods
        def presenter(&block)
          PresenterBlock.new(configuration, &block)
        end
      end
    end
  end
end
