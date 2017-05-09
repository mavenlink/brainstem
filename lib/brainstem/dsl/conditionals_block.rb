module Brainstem
  module Concerns
    module PresenterDSL
      class ConditionalsBlock < BaseBlock
        def request(name, action, *args)
          options = parse_args(args)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :request, action, options)
        end

        def model(name, action, *args)
          options = parse_args(args)
          configuration[:conditionals][name] = DSL::Conditional.new(name, :model, action, options)
        end
      end

      private

      def parse_args(args)
        if args.length == 1
          description = args.first
          if description.is_a?(String)
            deprecated_description_warning
            { info: description }
          else
            description
          end
        else
          super(args)
        end
      end
    end
  end
end
