module Brainstem
  module Concerns
    module PresenterDSL
      class ConditionalsBlock < BaseBlock
        def request(name, action, *args)
          description, options = parse_args(args)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :request, action, description, options)
        end

        def model(name, action, *args)
          description, options = parse_args(args)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :model, action, description, options)
        end
      end
    end
  end
end
