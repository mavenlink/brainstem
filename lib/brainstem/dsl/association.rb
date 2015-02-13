module Brainstem
  module DSL
    class Association
      attr_reader :name, :target_class, :description, :options

      def initialize(name, target_class, description, options)
        @name = name
        @target_class = target_class
        @description = description
        @options = options
      end
    end
  end
end
