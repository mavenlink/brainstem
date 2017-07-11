module Brainstem
  module Concerns
    module PresenterDSL
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

        def format_options(options)
          options.symbolize_keys
        end
      end
    end
  end
end
