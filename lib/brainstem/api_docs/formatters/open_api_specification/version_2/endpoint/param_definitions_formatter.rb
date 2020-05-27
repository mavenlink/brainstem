require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/compact'
require 'active_support/inflector'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/field_definitions/endpoint_param_formatter'
require 'brainstem/api_docs/formatters/markdown/helper'

#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module Endpoint
            class ParamDefinitionsFormatter < AbstractFormatter
              include Helper
              include ::Brainstem::ApiDocs::Formatters::Markdown::Helper

              attr_reader :output

              def initialize(endpoint)
                @endpoint    = endpoint
                @http_method = format_http_method(endpoint)
                @presenter   = endpoint.presenter
                @output      = []
              end

              def call
                format_path_params!

                if presenter
                  if endpoint.action == 'index'
                    format_pagination_params!
                    format_search_param!
                    format_only_param!
                    format_sort_order_params!
                    format_filter_params!
                  end

                  if http_method != 'delete'
                    format_optional_params!
                    format_include_params!
                  end
                end

                format_query_params!
                format_body_params!

                output
              end

              ################################################################################
              private
              ################################################################################

              attr_reader :endpoint, :presenter, :http_method

              def format_path_params!
                path_params.each do |param|
                  model_name = param.match(/_id/) ? param.split('_id').first : 'model'

                  output << {
                    'in'          => 'path',
                    'name'        => param,
                    'required'    => true,
                    'type'        => 'integer',
                    'description' => "The ID of the #{model_name.humanize}."
                  }
                end
              end

              def path_params
                endpoint.path
                  .gsub('(.:format)', '')
                  .scan(/(:(?<param>\w+))/)
                  .flatten
              end

              def nested_properties(param_config)
                param_config.except(:_config)
              end

              def format_pagination_params!
                output << format_query_param(:page, type: 'integer', default: 1)
                output << format_query_param(:per_page, type: 'integer', default: 20, maximum: 200)
              end

              def format_search_param!
                return if presenter.nil? || !presenter.searchable? || presenter.search_configuration[:nodoc].present?

                output << format_query_param(:search, presenter.search_configuration)
              end

              def format_only_param!
                output << format_query_param(:only,
                  type: 'string',
                  info: <<-DESC.strip_heredoc
                    Allows you to request one or more resources directly by ID. Multiple IDs can be supplied
                    in a comma separated list, like `GET /api/v1/workspaces.json?only=5,6,7`.
                  DESC
                )
              end

              def format_sort_order_params!
                return if presenter.nil? || (valid_sort_orders = presenter.valid_sort_orders).empty?

                sort_orders = valid_sort_orders.map { |sort_name, sort_config|
                  if sort_config[:direction]
                    [md_inline_code("#{sort_name}:asc"), md_inline_code("#{sort_name}:desc")]
                  else
                    md_inline_code(sort_name)
                  end
                }.flatten.sort

                description = <<-DESC.strip_heredoc
                  Supply `order` with the name of a valid sort field for the endpoint and a direction.

                  Valid values: #{sort_orders.to_sentence}.
                DESC

                output << format_query_param('order',
                  info:    description,
                  type:    'string',
                  default: presenter.default_sort_order
                )
              end

              def format_filter_params!
                return if presenter.nil?

                presenter.valid_filters.each do |filter_name, filter_config|
                  output << format_query_param(filter_name, filter_config)
                end
              end

              def format_optional_params!
                return if presenter.nil? || (optional_field_names = presenter.optional_field_names).empty?

                output << format_query_param('optional_fields',
                  info:      'Allows you to request one or more optional fields as an array',
                  type:      'array',
                  item_type: 'string',
                  items:     optional_field_names
                )
              end

              def format_include_params!
                return if presenter.nil? || presenter.valid_associations.empty?

                output << format_query_param('include',
                  type: 'string',
                  info: include_params_description
                )
              end

              def include_params_description
                result = "Any of the below associations can be included in your request by providing the `include` "\
                         "param, e.g. `include=association1,association2`.\n"

                presenter.valid_associations
                  .sort_by { |_, association| association.name }
                  .each do |_, association|

                  text = md_inline_code(association.name)
                  text += " (#{ association.target_class.to_s })"

                  desc = format_sentence(association.description)
                  if association.options && association.options[:restrict_to_only]
                    desc += "  Restricted to queries using the #{md_inline_code("only")} parameter."
                  end

                  result << md_li(text + (desc.present? ? " - #{desc}" : ''))
                end

                result
              end

              def format_query_params!
                endpoint.params_configuration_tree.each do |param_name, param_config|
                  next if nested_properties(param_config).present?

                  output << format_query_param(param_name, param_config[:_config])
                end

                # Sort all query params by required attribute & alphabetically.
                output.sort_by! { |param| [(param['required'] ? 0 : 1), param['name']] }
              end

              def format_query_param(param_name, param_config)
                type_data = type_and_format(param_config[:type], param_config[:item_type])
                if type_data.nil?
                  raise "Unknown Brainstem Param type encountered(#{param_config[:type]}) for param #{param_name}"
                end

                if param_config[:type].to_s == 'array'
                  type_data[:items].merge!(
                    {
                      'type'    => param_config[:item_type],
                      'enum'    => param_config[:items],
                      'default' => param_config[:default],
                    }.compact
                  )
                else
                  type_data.merge!(
                    'default'     => param_config[:default],
                    'minimum'     => param_config[:minimum],
                    'maximum'     => param_config[:maximum]
                  )
                end

                {
                  'in'          => 'query',
                  'name'        => param_name.to_s,
                  'required'    => param_config[:required],
                  'description' => format_sentence(param_config[:info]).presence,
                }.merge(type_data).compact
              end

              def format_body_params!
                properties, additional_properties = split_properties(endpoint.params_configuration_tree)
                formatted_body_params = format_field_properties(properties)
                formatted_dynamic_key_params = format_field_properties(additional_properties)
                return if formatted_body_params.blank? && formatted_dynamic_key_params.blank?

                output << {
                  'in'          => 'body',
                  'required'    => true,
                  'name'        => 'body',
                  'schema'      => {
                    'type'       => 'object',
                    'properties' => formatted_body_params,
                    'additionalProperties' => formatted_dynamic_key_params,
                  }.with_indifferent_access.reject { |_, v| v.blank? },
                }
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

              def format_field_properties(branches)
                branches.inject(ActiveSupport::HashWithIndifferentAccess.new) do |buffer, (field_name, field_config)|
                  if dynamic_key_field?(field_config)
                    formatted_field('Dynamic Key Field', field_config)
                  else
                    buffer[field_name.to_s] = formatted_field(field_name, field_config) if nested_properties(field_config).present?
                    buffer
                  end
                end
              end

              def dynamic_key_field?(param_config)
                param_config[:_config][:dynamic_key].presence
              end

              def formatted_field(param_name, param_data)
                Brainstem::ApiDocs::FORMATTERS[:endpoint_param][:oas_v2].call(
                  endpoint,
                  param_name,
                  param_data
                )
              end
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:parameters][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::Endpoint::ParamDefinitionsFormatter.method(:call)
