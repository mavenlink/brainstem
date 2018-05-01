require 'active_support/core_ext/string/inflections'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
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
            definition.merge! description: presenter.description.to_s.strip
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
              if nested_field?(field)
                buffer[name.to_s] = case field.type
                  when 'hash'
                    {
                      type: 'object',
                      properties: format_field_branch(field.to_h)
                    }.with_indifferent_access
                  when 'array'
                    {
                      type: 'array',
                      items: {
                        type: 'object',
                        properties: format_field_branch(field.to_h)
                      }
                    }.with_indifferent_access
                end
              else
                buffer[name.to_s] = format_field_leaf(field)
              end

              buffer
            end
          end

          def nested_field?(field)
            field.respond_to?(:configuration)
          end

          def format_field_leaf(field)
            field_data = type_and_format(field.type, field.options[:item_type])

            unless field_data
              raise "Unknown Brainstem Field type encountered(#{field.type}) for field #{field.name}"
            end

            field_data.merge!(description: format_description_for(field))
            field_data.delete(:description) if field_data[:description].blank?

            field_data
          end

          def format_description_for(field)
            field_description = field.description.to_s
            field_description << format_conditional_description(field.options)
            field_description << "\nOnly returned when requested through the optional_fields param.\n" if field.optional?
            field_description.try(:chomp!)
            field_description
          end

          def format_conditional_description(field_options)
            return '' if field_options[:if].blank?

            conditions = field_options[:if]
              .reject { |cond| presenter.conditionals[cond].options[:nodoc] }
              .map    { |cond| presenter.conditionals[cond].description.to_s }
              .delete_if(&:empty?)
              .join(' and ')

            conditions.present? ? "\nVisible when #{conditions}.\n" : ''
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter][:oas_v2] = \
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::PresenterFormatter.method(:call)
