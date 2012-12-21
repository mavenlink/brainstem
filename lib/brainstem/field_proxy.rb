module Brainstem

  # FieldProxy acts as a standin for associations and optional fields.
  # @api private
  class FieldProxy
    # @!attribute [r] method_name
    # @return [Symbol] The name of the method that is being proxied.
    attr_reader :method_name

    # @!attribute [r] optional
    # @return [Boolean] Whether this field is optional or not (defaults to +false+)
    attr_reader :optional

    # @param method_name The name of the method being proxied. Not required if
    #   a block is passed instead.
    # @option options [Boolean] :optional Declares the field being proxied to be optional.
    def initialize(method_name = nil, options = {}, &block)
      if block_given?
        raise ArgumentError, "Method name is invalid with a block" if method_name
        @block = block
      elsif method_name
        @method_name = method_name
      else
        raise ArgumentError, "Method name or block is required"
      end
      @optional = options[:optional]
    end

    # Call the method or block being proxied.
    # @param model The object to call the proxied method on.
    # @return The value returned by calling the method or block being proxied.
    def call(model)
      @block ? @block.call : model.send(@method_name)
    end
  end

end