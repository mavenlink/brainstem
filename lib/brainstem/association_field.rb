require 'brainstem/field_proxy'

module Brainstem
  class AssociationField < FieldProxy

    attr_accessor :json_name

    def initialize(method_name, options = {}, &block)
      @json_name = options[:json_name]
      super
    end

  end
end
