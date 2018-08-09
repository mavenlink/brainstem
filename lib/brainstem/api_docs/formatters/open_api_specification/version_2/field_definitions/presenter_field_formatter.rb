require 'brainstem/api_docs'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module FieldDefinitions
            class PresenterFieldFormatter < AbstractFormatter
              include Helper
              
              def initialize(presenter, field)
                @presenter = presenter
                @field = field
              end

              def format
                format_field(@field)
              end
              alias_method :call, :format

              private
              
              attr_reader :presenter

              def has_properties?(field)
                field.respond_to?(:configuration)
              end

              def format_field(field)
                if field.options[:nested_levels]
                  format_nested_array_field(field)
                elsif has_properties?(field)
                  format_nested_field(field)
                else
                  format_simple_field(field)
                end
              end

              def format_nested_array_field(field)
                field_properties_data, nested_levels = format_array_items(field)

                format_nested_array_parent(nested_levels, field_properties_data, format_description(field))
              end

              def format_array_items(field)
                field_nested_levels = field.options[:nested_levels]

                if has_properties?(field)
                  [format_nested_field(field, false), field_nested_levels - 1]
                else
                  [type_and_format(field.options[:item_type]), field_nested_levels]
                end
              end

              def format_nested_array_parent(nested_level, formatted_data, description = nil)
                if nested_level == 1
                  {
                    'type' => 'array',
                    'description' => description,
                    'items' => formatted_data
                  }
                else
                  {
                    'type' => 'array',
                    'description' => description,
                    'items' => format_nested_array_parent(nested_level - 1, formatted_data)
                  }
                end.with_indifferent_access.reject { |_, v| v.blank? }
              end

              def format_nested_field(field, include_description = true)
                case field.type
                  when 'hash'
                    format_object_field(field, include_description)
                  when 'array'
                    {
                      type: 'array',
                      description: include_description && format_description(field),
                      items: format_object_field(field, false)
                    }
                end.with_indifferent_access.reject { |_, v| v.blank? }
              end

              def format_object_field(field, include_description = true)
                {
                  type: 'object',
                  description: include_description && format_description(field),
                  properties: format_field_properties(field.to_h),
                }.with_indifferent_access.reject { |_, v| v.blank? }
              end

              def format_simple_field(field)
                field_data = type_and_format(field.type) || raise(invalid_type_error_message(field))
                field_data.merge!(description: format_description(field))
                field_data.with_indifferent_access.reject { |_, v| v.blank? }
              end
              
              def invalid_type_error_message(field)
                <<-MSG.strip_heredoc
                  Unknown Brainstem Field type encountered(#{field.type}) for field #{field.name}
                  in #{presenter.target_class.to_s}.
                MSG
              end

              def format_field_properties(branches)
                branches.inject(ActiveSupport::HashWithIndifferentAccess.new) do |buffer, (field_name, field)|
                  buffer[field_name.to_s] = format_field(field)
                  buffer
                end
              end

              def format_description(field)
                field_description = format_sentence(field.description) || ''
                field_description << format_conditional_description(field.options)
                if field.optional?
                  field_description << "\nOnly returned when requested through the optional_fields param.\n"
                end
                field_description.try(:chomp!)
                field_description
              end

              def format_conditional_description(field_options)
                return '' if field_options[:if].blank?

                conditions = field_options[:if]
                  .reject { |cond| presenter.conditionals[cond].options[:nodoc] }
                  .map    { |cond| uncapitalize(presenter.conditionals[cond].description) }
                  .delete_if(&:empty?)
                  .uniq
                  .to_sentence

                conditions.present? ? "\nVisible when #{conditions}.\n" : ''
              end
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:presenter_field][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::FieldDefinitions::PresenterFieldFormatter.method(:call)

