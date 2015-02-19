module Brainstem
  module DSL
    class Configuration
      def initialize(parent_configuration = nil)
        @parent_configuration = parent_configuration || {}
        @storage = {}
      end

      def [](key)
        get!(key)
      end

      def []=(key, value)
        existing_value = get!(key)
        if existing_value.is_a?(Configuration)
          raise 'You cannot override a nested value'
        elsif existing_value.is_a?(InheritableAppendSet)
          raise 'You cannot override an inheritable array once set'
        else
          @storage[key] = value
        end
      end

      def nest!(key)
        get!(key)
        @storage[key] ||= Configuration.new
      end

      def array!(key)
        get!(key)
        @storage[key] ||= InheritableAppendSet.new
      end

      def keys
        @parent_configuration.keys | @storage.keys
      end

      def length
        keys.length
      end

      def each
        keys.each do |key|
          yield key, get!(key)
        end
      end

      delegate :empty?, to: :keys

      private

      def get!(key)
        @storage[key] || begin
          if @parent_configuration[key].is_a?(Configuration)
            @storage[key] = Configuration.new(@parent_configuration[key])
          elsif @parent_configuration[key].is_a?(InheritableAppendSet)
            @storage[key] = InheritableAppendSet.new(@parent_configuration[key])
          else
            @parent_configuration[key]
          end
        end
      end

      class InheritableAppendSet
        def initialize(parent_array = nil)
          @parent_array = parent_array || []
          @storage = []
        end

        def push(item)
          @storage.push item
        end
        alias_method :<<, :push

        def concat(items)
          @storage.concat items
        end

        def to_a
          @parent_array.to_a + @storage
        end

        delegate :each, :empty?, to: :to_a
      end
    end
  end
end