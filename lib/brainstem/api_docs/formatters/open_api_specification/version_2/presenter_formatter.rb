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
              sort_properties!

              output.merge!(presenter.target_class => definition.reject {|_, v| v.blank?})
            end

            #####################################################################
            private
            #####################################################################

            def format_title!
              definition.merge! title: presenter_title(presenter)
            end

            def sort_properties!
              definition[:properties] = definition[:properties].sort.each_with_object({}) do |(key, val), obj|
                obj[key] = val
              end if definition[:properties]
            end

            def format_description!
              definition.merge! description: format_sentence(presenter.description)
            end

            def format_type!
              definition.merge! type: 'object'
            end

            def format_fields!
              return unless presenter.valid_fields.any? || presenter.valid_associations.any?

              properties = format_field_branch(presenter.valid_fields)
              with_associations = format_field_associations(properties)

              definition.merge! properties: with_associations
            end

            def format_field_branch(branch)
              branch.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |(name, field), buffer|
                buffer[name.to_s] = format_field(field)
              end
            end

            def format_field_associations(properties)
              presenter.valid_associations.each_with_object(properties) do |(name, association), props|
                if association.polymorphic?
                  key = association.name + "_ref"
                  props[key] = {
                    type: 'object',
                    description: association_description(key, name),
                    properties: {
                      key: type_and_format(:string),
                      id: type_and_format(:string)
                    }
                  }
                  next
                end

                key = association_key(association)
                description = association_description(key, association.name)
                formatted_type = if association.type == :has_many
                  type_and_format(:array, :string)
                else
                  type_and_format(:string)
                end.merge(description: description)

                props[key] = formatted_type unless props[key]
              end
            end

            def association_description(key, name)
              ["`#{key}` will only be included in the response if `#{name}` is in the list of included associations.",
                "See <a href='#section/Includes'>include</a> section for usage."].join(' ')
            end

            def association_key(association)
              if association.response_key
                association.response_key
              else
                key = association.name.singularize
                association.type == :has_many ? "#{key}_ids" : "#{key}_id"
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
