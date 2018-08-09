require 'active_support/core_ext/string/inflections'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/field_definitions/presenter_field_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          class PresenterFormatter < AbstractFormatter
            include Helper

            def initialize(presenter, options = {})
              self.presenter  = presenter
              self.definition = ActiveSupport::HashWithIndifferentAccess.new
              self.output     = ActiveSupport::HashWithIndifferentAccess.new

              super options
            end

            attr_accessor :presenter,
                          :output,
                          :definition,
                          :presented_class

            def call
              return {} if presenter.nodoc?

              format_title!
              format_description!
              format_type!
              format_fields!

              output.merge!(presenter.target_class => definition.reject {|_, v| v.blank?})
            end

            #####################################################################
            private
            #####################################################################

            def format_title!
              definition.merge! title: presenter_title(presenter)
            end

            def format_description!
              definition.merge! description: format_sentence(presenter.description)
            end

            def format_type!
              definition.merge! type: 'object'
            end

            def format_fields!
              return unless presenter.valid_fields.any?

              definition.merge! properties: format_field_branch(presenter.valid_fields)
            end

            def format_field_branch(branch)
              branch.inject(ActiveSupport::HashWithIndifferentAccess.new) do |buffer, (name, field)|
                buffer[name.to_s] = format_field(field)
                buffer
              end
            end
            
            def format_field(field)
              Brainstem::ApiDocs::FORMATTERS[:presenter_field][:oas_v2].call(presenter, field)
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::PresenterFormatter.method(:call)
