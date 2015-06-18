module Brainstem
  module Concerns
    module PresenterDSL
      class ConditionalsBlock < BaseBlock
        def request(name, action, description = nil)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :request, action, description)
        end

        def model(name, action, description = nil)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :model, action, description)
        end
      end
    end
  end
end
