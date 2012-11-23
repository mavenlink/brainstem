require 'api_presenter/field_proxy'

module ApiPresenter
  class AssociationField < FieldProxy

    attr_reader :association_name
    attr_accessor :json_name

    def initialize(method_name = nil, options = {}, &block)
      @json_name, @association_name = options[:json_name], options[:association_name]
      super
    end

  end
end