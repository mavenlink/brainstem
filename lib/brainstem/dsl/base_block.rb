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

        def parse_args(args)
          options = args.last.kind_of?(Hash) ? args.pop : {}
          maybe_description = args.shift

          if maybe_description.kind_of?(Hash)
            options = options.merge(maybe_description)
          elsif maybe_description.present?
            deprecated_description_warning
            options[:info] = maybe_description
          end

          options.symbolize_keys
        end

        def deprecated_description_warning
          ActiveSupport::Deprecation.warn(
           'DEPRECATION_WARNING: Specifying description as the last parameter will be deprecated in the next version.' \
           'Description can be specified with the `info` key in a hash. e.g. { info: "My description" }',
           caller
          )
        end
      end
    end
  end
end
