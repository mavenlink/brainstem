require 'active_support/core_ext/hash/except'
require 'active_support/inflector'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'


#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class EndpointParamsFormatter < AbstractFormatter
          include Helper

          attr_reader :output

          def initialize(endpoint)
            @endpoint = endpoint
            @output = []
          end

          def call
            format_path_params!

            # TODO:
            # format_pagination_params for index
            # format_search_params for index
            # format_sorting_params for index
            # format_only_params for index

            # format_include_params

            format_query_params!
            format_body_params!

            output
          end


          ################################################################################
          private
          ################################################################################

          attr_reader :endpoint

          def format_path_params!
            path_params.each do |param|
              model_name = param.match(/_id/) ? param.split('_id').first : 'model'

              output << {
                'in'          => 'path',
                'name'        => param,
                'required'    => true,
                'type'        => 'integer',
                'description' => "the ID of the #{model_name.humanize}"
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

          def format_query_params!
            endpoint.params_configuration_tree.each do |param_name, param_config|
              next if nested_properties(param_config).present?

              output << format_query_param(param_name, param_config[:_config])
            end
          end

          def format_query_param(param_name, param_config)
            type_data = type_and_format(param_config[:type], param_config[:item_type])

            if type_data.nil?
              raise "Unknown Brainstem Param type encountered(#{param_config[:type]}) for param #{param_name}"
            end

            {
              'in'          => 'query',
              'name'        => param_name,
              'required'    => param_config[:required],
              'description' => param_config[:info].to_s.strip
            }.merge(type_data).reject { |_, v| v.blank? }
          end

          def format_body_params!
            endpoint.params_configuration_tree.each do |param_name, param_config|
              next if nested_properties(param_config).blank?

              output << format_body_param(param_name, param_config)
            end
          end

          # TODO: Array of recursive attributes
          def format_body_param(param_name, param_data)
            {
              'in'          => 'body',
              'required'    => true,
              'name'        => param_name,
              'description' => param_data[:_config][:info].to_s.strip,
              'schema'      => {
                'type'       => 'object',
                'properties' => format_param_branch(nested_properties(param_data))
              },
            }.reject { |_, v| v.blank? }
          end

          def format_param_branch(branch)
            branch.inject(ActiveSupport::HashWithIndifferentAccess.new) do |buffer, (param_name, param_data)|
              nested_properties = nested_properties(param_data)
              param_config = param_data[:_config]

              branch_schema = if nested_properties.present?
                case param_config[:type].to_s
                  when 'hash'
                    { type: 'object', properties: format_param_branch(nested_properties) }
                  when 'array'
                    {
                      type: 'array',
                      items: { type: 'object', properties: format_param_branch(nested_properties) }
                    }
                  else
                    raise "Unknown Brainstem Param type encountered(#{param_config[:type]}) for param #{param_name}"
                end
              else
                param_data = type_and_format(param_config[:type].to_s, param_config[:item_type])
                if param_data.blank?
                  raise "Unknown Brainstem Param type encountered(#{param_config[:type]}) for param #{param_name}"
                end
                param_data
              end

              buffer[param_name.to_s] = {
                title:       param_name,
                description: param_config[:info].to_s.strip,
                required:    param_config[:required]
              }.merge(branch_schema).reject { |_, v| v.blank? }

              buffer
            end
          end
        end
      end
    end
  end
end
