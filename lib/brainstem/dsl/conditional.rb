module Brainstem
  module DSL
    class Conditional
      attr_reader :name, :type, :action, :description

      def initialize(name, type, action, description)
        @name = name
        @type = type
        @action = action
        @description = description
      end
    end
  end
end
