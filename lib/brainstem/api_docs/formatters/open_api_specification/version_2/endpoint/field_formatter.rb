require 'active_support/core_ext/hash/except'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module Endpoint
            class FieldFormatter
              include Helper

              def initialize(param_tree, options = {})
                @param_tree = param_tree
                @options = options
              end

              def format
                response_config = @param_tree[:_config]
                response_branches = @param_tree.except(:_config)

                format_response_field(response_config, response_branches)
              end

              private

              def include_required?
                !!@options[:include_required]
              end

              def format_array_parent(nested_level, formatted_data)
                if nested_level == 1
                  {
                    'type' => 'array',
                    'items' => formatted_data
                  }
                else
                  {
                    'type' => 'array',
                    'items' => format_array_parent(nested_level - 1, formatted_data)
                  }
                end
              end

              def format_nested_array(field_config, field_branches)
                field_nested_levels = field_config[:nested_levels]

                field_branches_data, nested_levels = if field_branches.present?
                  [formed_nested_field(field_config, field_branches), field_nested_levels - 1]
                else
                  [type_and_format(field_config[:item_type]), field_nested_levels]
                end
                format_array_parent(nested_levels, field_branches_data)
              end

              def format_response_field(field_config, field_branches)
                if field_config[:nested_levels]
                  format_nested_array(field_config, field_branches)
                elsif field_branches.present?
                  formed_nested_field(field_config, field_branches)
                else
                  format_response_leaf(field_config)
                end
              end

              def format_response_leaf(field_config)
                field_data = type_and_format(field_config[:type], field_config[:item_type])

                unless field_data
                  raise "Unknown Brainstem Field type encountered(#{field_config[:type]}) for field #{field_config[:name]}"
                end

                field_data.merge!(description: format_sentence(field_config[:info])) if field_config[:info].present?
                field_data
              end

              def formed_nested_field(field_config, field_branches)
                result = case field_config[:type]
                when 'hash'
                  {
                    type: 'object',
                    description: format_sentence(field_config[:info]),
                    properties: format_response_branches(field_branches),
                    required: include_required? && required_children(field_branches)
                  }
                when 'array'
                  {
                    type: 'array',
                    description: format_sentence(field_config[:info]),
                    items: {
                      type: 'object',
                      properties: format_response_branches(field_branches),
                      required: include_required? && required_children(field_branches)
                    }.with_indifferent_access.reject { |_, v| v.blank? }
                  }
                end

                result.with_indifferent_access.reject { |_, v| v.blank? }
              end

              def required_children(children)
                children.select { |_, field_data| field_data[:_config][:required] }.keys
              end

              def format_response_branches(branches)
                branches.inject(ActiveSupport::HashWithIndifferentAccess.new) do |buffer, (field_name, field_config)|
                  config = field_config[:_config]
                  branches = field_config.except(:_config)

                  buffer[field_name.to_s] = format_response_field(config, branches)
                  buffer
                end
              end
            end
          end
        end
      end
    end
  end
end

