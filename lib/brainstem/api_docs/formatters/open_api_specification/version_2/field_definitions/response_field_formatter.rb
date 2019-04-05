require 'brainstem/api_docs'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module FieldDefinitions
            class ResponseFieldFormatter < AbstractFormatter
              include Helper

              def initialize(endpoint, param_name, param_tree)
                @endpoint = endpoint
                @param_name = param_name
                @param_tree = param_tree
              end

              def format
                field_config = @param_tree[:_config]
                field_properties = @param_tree.except(:_config)
  
                format_field(field_config, field_properties)
              end
              alias_method :call, :format

              private

              def format_field(field_config, field_branches)
                if field_config[:nested_levels]
                  format_nested_array_field(field_config, field_branches)
                elsif field_branches.present?
                  format_nested_field(field_config, field_branches)
                else
                  format_simple_field(field_config)
                end
              end

              def format_nested_array_field(field_config, field_properties)
                field_properties_data, nested_levels = format_array_items(field_config, field_properties)
                
                format_nested_array_parent(nested_levels, field_properties_data)
              end
              
              def format_array_items(field_config, field_properties)
                field_nested_levels = field_config[:nested_levels]
                
                if field_properties.present?
                  [format_nested_field(field_config, field_properties), field_nested_levels - 1]
                else
                  [type_and_format(field_config[:item_type]), field_nested_levels]
                end
              end

              def format_nested_array_parent(nested_level, formatted_data)
                if nested_level == 1
                  {
                    'type' => 'array',
                    'items' => formatted_data
                  }
                else
                  {
                    'type' => 'array',
                    'items' => format_nested_array_parent(nested_level - 1, formatted_data)
                  }
                end
              end

              def format_nested_field(field_config, field_properties)
                case field_config[:type]
                  when 'hash'
                    format_object_field(field_config, field_properties)
                  when 'array'
                    {
                      type: 'array',
                      description: format_description(field_config),
                      items: format_object_field(field_config, field_properties, false)
                    }
                end.with_indifferent_access.reject { |_, v| v.blank? }
              end

              def format_object_field(field_config, field_properties, include_description = true)
                properties, additional_properties = split_properties(field_properties)

                {
                  type: 'object',
                  description: include_description && format_description(field_config),
                  properties: format_field_properties(properties),
                  additionalProperties: format_field_properties(additional_properties),
                }.with_indifferent_access.reject { |_, v| v.blank? }
              end

              def split_properties(field_properties)
                split_properties = field_properties.each_with_object({ properties: {}, additional_properties: {} }) do |(field_name, field_config), acc|
                  if field_config[:_config][:dynamic_key]
                    acc[:additional_properties][field_name] = field_config
                  else
                    acc[:properties][field_name] = field_config
                  end
                end

                [split_properties[:properties], split_properties[:additional_properties]]
              end

              def format_simple_field(field_config)
                field_data = type_and_format(field_config[:type], field_config[:item_type])
                raise(invalid_type_error_message(field_config)) unless field_data
                field_data.merge!(description: format_sentence(field_config[:info])) if field_config[:info].present?
                field_data
              end

              def invalid_type_error_message(field_config)
                <<-MSG.strip_heredoc
                  Unknown Brainstem Field type encountered(#{field_config[:type]}) for field #{field_config[:name]}
                  in #{@endpoint.controller_name} for #{@endpoint.action} action. 
                MSG
              end

              def format_field_properties(branches)
                branches.inject(ActiveSupport::HashWithIndifferentAccess.new) do |buffer, (field_name, field_config)|
                  config = field_config[:_config]
                  branches = field_config.except(:_config)

                  if config[:dynamic_key]
                    format_field(config, branches)
                  else
                    buffer[field_name.to_s] = format_field(config, branches)
                    buffer
                  end
                end
              end
              
              def format_description(field_config)
                format_sentence(field_config[:info])
              end
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:response_field][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::FieldDefinitions::ResponseFieldFormatter.method(:call)
