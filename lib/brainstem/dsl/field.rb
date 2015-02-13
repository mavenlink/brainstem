module Brainstem
  module DSL
    class Field
      attr_reader :name, :type, :description, :options

      def initialize(name, type, description, options)
        @name = name
        @type = type
        @description = description
        @options = options
      end
    end
  end
end
