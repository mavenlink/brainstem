require 'active_support/core_ext/hash/except'
require 'active_support/inflector'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'
require 'forwardable'

#
# Responsible for formatting a response for an endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class EndpointResponseFormatter < AbstractFormatter
          include Helper

          attr_reader :output

          def initialize(endpoint)
            @endpoint    = endpoint
            @http_method = format_http_method(endpoint)
            @presenter   = endpoint.presenter
            @model_name  = presenter ? presenter_title(presenter) : "object"
            @output      = ActiveSupport::HashWithIndifferentAccess.new
          end

          def call
            if endpoint.custom_response_configuration_tree.present?
              format_custom_response!
            elsif http_method == 'delete'
              format_delete_response!
            else
              format_schema_response!
            end
            format_error_responses!

            output
          end


          ################################################################################
          private
          ################################################################################

          attr_reader :endpoint,
                      :presenter,
                      :model_name,
                      :http_method

          def format_delete_response!
            output.merge! '204' => { description: success_response_description }
          end

          def nested_properties(param_config)
            param_config.except(:_config)
          end

          def success_response_description
            case http_method
              when 'post'
                "#{model_name} has been created"
              when 'put', 'patch'
                "#{model_name} has been updated"
              when 'delete'
                "#{model_name} has been deleted"
              else
                "A list of #{model_name.pluralize} have been retrieved"
            end
          end

          def format_schema_response!
            return if presenter.nil?

            brainstem_key = presenter.brainstem_keys.first
            model_klass   = presenter.target_class

            output.merge! '200' => {
              description: success_response_description,
              schema: {
                type: 'object',
                properties: {
                  count: type_and_format('integer'),
                  meta: {
                    type: 'object',
                    properties: {
                      count:       type_and_format('integer'),
                      page_count:  type_and_format('integer'),
                      page_number: type_and_format('integer'),
                      page_size:   type_and_format('integer'),
                    }
                  },
                  results: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        key: type_and_format('string'),
                        id:  type_and_format('string')
                      }
                    }
                  },
                  brainstem_key => {
                    type: 'object',
                    additionalProperties: {
                      '$ref' => "#/definitions/#{model_klass}"
                    }
                  }
                }
              }
            }
          end

          def format_error_responses!
            output.merge!(
              '400' => { description: 'Bad Request',            schema: { '$ref' => '#/definitions/Errors' }  },
              '401' => { description: 'Unauthorized request',   schema: { '$ref' => '#/definitions/Errors' }  },
              '403' => { description: 'Forbidden request',      schema: { '$ref' => '#/definitions/Errors' }  },
              '404' => { description: 'Page Not Found',         schema: { '$ref' => '#/definitions/Errors' }  },
              '503' => { description: 'Service is unavailable', schema: { '$ref' => '#/definitions/Errors' }  }
            )
          end

          def format_custom_response!
            output.merge! '200' => {
              description: success_response_description,
              schema: format_response(endpoint.custom_response_configuration_tree)
            }
          end

          def format_response(response_tree)
            response_config   = response_tree[:_config]
            response_branches = response_tree.except(:_config)

            format_response_field(response_config, response_branches)
          end

          def format_response_field(field_config, field_branches)
            if field_branches.present?
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

            field_data.merge!(description: field_config[:info]) if field_config[:info].present?
            field_data
          end

          def formed_nested_field(field_config, field_branches)
            result = case field_config[:type]
              when 'hash'
                {
                  type: 'object',
                  description: field_config[:info],
                  properties: format_response_branches(field_branches)
                }
              when 'array'
                {
                  type: 'array',
                  description: field_config[:info],
                  items: {
                    type: 'object',
                    properties: format_response_branches(field_branches)
                  }
                }
            end

            result.with_indifferent_access.reject { |_, v| v.blank? }
          end

          def format_response_branches(branches)
            branches.inject(ActiveSupport::HashWithIndifferentAccess.new) do |buffer, (field_name, field_config)|
              config   = field_config[:_config]
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
