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
            @model_name  = presenter_title(presenter)
            @output      = ActiveSupport::HashWithIndifferentAccess.new
          end

          def call
            if http_method == 'delete'
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
        end
      end
    end
  end
end
