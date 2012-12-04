require 'api_presenter/field_proxy'

module ApiPresenter
  class AssociationField < FieldProxy

    attr_accessor :json_name

    def initialize(method_name, options = {}, &block)
      @json_name = options[:json_name]
      super
    end

  end
end