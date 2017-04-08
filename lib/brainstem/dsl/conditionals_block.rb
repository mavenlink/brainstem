module Brainstem
  module Concerns
    module PresenterDSL
      class ConditionalsBlock < BaseBlock
        def request(name, action, options = {})
          configuration[:conditionals][name] = DSL::Conditional.new(name, :request, action, format_options(options))
        end

        def model(name, action, options = {})
          configuration[:conditionals][name] = DSL::Conditional.new(name, :model, action, format_options(options))
        end
      end
    end
  end
end
