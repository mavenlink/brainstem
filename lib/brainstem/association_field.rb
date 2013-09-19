module Brainstem
  # AssociationField acts as a standin for associations.
  # @api private
  class AssociationField
    # @!attribute [r] method_name
    # @return [String] The name of the method that is being proxied.
    attr_reader :method_name

    # @!attribute [rw] json_name
    # @return [String] The name of the top-level JSON key for objects provided by this association.
    attr_accessor :json_name

    # @!attribute [rw] restrict_only
    # @return [Boolean] Option for this association to be restricted to only queries.
    attr_accessor :restrict_only

    # @!attribute [r] block
    # @return [Proc] The block to be called when fetching models instead of calling a method on the model
    attr_reader :block

    # @param method_name The name of the method being proxied. Not required if
    #   a block is passed instead.
    # @option options [Boolean] :json_name The name of the top-level JSON key for objects provided by this association.
    def initialize(*args, &block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      method_name = args.first.to_sym if args.first.is_a?(String) || args.first.is_a?(Symbol)
      @json_name = options[:json_name]
      @restrict_only = options[:restrict_only] || false
      if block_given?
        raise ArgumentError, "options[:json_name] is required when using a block" unless options[:json_name]
        raise ArgumentError, "Method name is invalid with a block" if method_name
        @block = block
      elsif method_name
        @method_name = method_name
      else
        raise ArgumentError, "Method name or block is required"
      end
    end

    # Call the method or block being proxied.
    # @param model The object to call the proxied method on.
    # @return The value returned by calling the method or block being proxied.
    def call(model)
      @block ? @block.call(model) : model.send(@method_name)
    end
  end
end
