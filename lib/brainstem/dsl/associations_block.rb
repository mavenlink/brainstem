module Brainstem
  module Concerns
    module PresenterDSL
      class AssociationsBlock < BaseBlock
        def association(name, target_class, *args)
          options = parse_args(args)
          configuration[:associations][name] = DSL::Association.new(name, target_class, block_options.merge(options))
        end
      end
    end
  end
end
