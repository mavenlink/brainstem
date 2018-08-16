require 'active_support/core_ext/hash/except'
require 'active_support/inflector'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/field_definitions/response_field_formatter'
require 'forwardable'

#
# Responsible for formatting a response for an endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module Endpoint
            class ResponseDefinitionsFormatter < AbstractFormatter
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
                    "#{model_name} has been created."
                  when 'put', 'patch'
                    "#{model_name} has been updated."
                  when 'delete'
                    "#{model_name} has been deleted."
                  else
                    "A list of #{model_name.pluralize} have been retrieved."
                end
              end

              def format_schema_response!
                return if presenter.nil?

                output.merge! '200' => {
                  description: success_response_description,
                  schema: {
                    type: 'object',
                    properties: properties
                  }
                }
              end

              def properties
                brainstem_key = presenter.brainstem_keys.first
                model_klass = presenter.target_class

                {
                  count: type_and_format('integer'),
                  meta: {
                    type: 'object',
                    properties: {
                      count: type_and_format('integer'),
                      page_count: type_and_format('integer'),
                      page_number: type_and_format('integer'),
                      page_size: type_and_format('integer'),
                    }
                  },
                  results: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        key: type_and_format('string'),
                        id: type_and_format('string')
                      }
                    }
                  },
                  brainstem_key => {
                    type: 'object',
                    additionalProperties: {
                      '$ref' => "#/definitions/#{model_klass}"
                    }
                  }
                }.merge(associated_properties)
              end

              def associated_properties
                presenter.valid_associations.each_with_object({}) do |(_key, association), obj|
                  if association.polymorphic?
                    associations = association.polymorphic_classes || []
                    associations.each do |assoc|
                      association_reference(assoc, obj)
                    end
                  else
                    association_reference(association.target_class, obj)
                  end
                end
              end

              def association_reference(target_class, obj)
                assoc_presenter = presenter.find_by_class(target_class)
                brainstem_key = assoc_presenter.brainstem_keys.first
                return if assoc_presenter.nodoc?

                obj[brainstem_key] = {
                  type: 'object',
                  additionalProperties: {
                    '$ref' => "#/definitions/#{target_class.to_s}"
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
                  schema: format_response!
                }
              end

              def format_response!
                Brainstem::ApiDocs::FORMATTERS[:response_field][:oas_v2].call(
                  endpoint,
                  'schema',
                  endpoint.custom_response_configuration_tree
                )
              end
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:response][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::Endpoint::ResponseDefinitionsFormatter.method(:call)
