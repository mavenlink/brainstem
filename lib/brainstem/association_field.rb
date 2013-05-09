module Brainstem
  # AssociationField acts as a standin for associations.
  # @api private
  class AssociationField
    # @!attribute [r] method_name
    # @return [String] The name of the method that is being proxied.
    attr_reader :method_name

    # @!attribute [r] json_name
    # @return [String] The name of the top-level JSON key for objects provided by this association.
    attr_accessor :json_name

    # @!attribute [r] block
    # @return [Proc] The block to be called when fetching models instead of calling a method on the model
    attr_reader :block

    # @param method_name The name of the method being proxied. Not required if
    #   a block is passed instead.
    # @option options [Boolean] :json_name The name of the top-level JSON key for objects provided by this association.
    def initialize(*args, &block)
      method_name = nil
      options = {}
      args.each do |arg|
        if arg.is_a?(String) || arg.is_a?(Symbol)
          method_name = arg.to_sym
        elsif arg.is_a?(Hash)
          options = arg
        end
      end
      @json_name = options[:json_name]
      if block_given?
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
