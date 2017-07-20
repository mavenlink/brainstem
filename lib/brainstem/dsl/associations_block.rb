module Brainstem
  module Concerns
    module PresenterDSL
      class AssociationsBlock < BaseBlock
        def association(name, target_class, options = {})
          configuration[:associations][name] = DSL::Association.new(
            name,
            target_class,
            block_options.merge(format_options(options))
          )
        end
      end
    end
  end
end
