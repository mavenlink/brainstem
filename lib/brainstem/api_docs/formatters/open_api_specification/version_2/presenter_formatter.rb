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
              presenter.valid_associations.each_with_object(properties) do |(_name, association), props|
                if association.foreign_key
                  case association.type
                  when :belongs_to, :has_one
                    props[association.foreign_key] = type_and_format(:integer).merge(description: association.description) unless props[association.foreign_key]
                  when :has_many
                    prop_key = "#{association.foreign_key}s"
                    props[prop_key] = type_and_format(:array, :integer).merge(description: association.description) unless props[prop_key]
                  end
                end

                if association.polymorphic?
                  props[association.name + "_ref"] = {
                    type: 'object',
                    description: association.description,
                    properties: {
                      key: type_and_format(:string),
                      id: type_and_format(:string)
                    }
                  }
                end
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
