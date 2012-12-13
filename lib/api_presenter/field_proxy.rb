module ApiPresenter

  class FieldProxy
    attr_reader :method_name, :optional

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

    def call(model)
      @block ? @block.call : model.send(@method_name)
    end
  end

end