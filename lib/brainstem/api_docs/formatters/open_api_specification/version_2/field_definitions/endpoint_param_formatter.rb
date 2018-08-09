require 'brainstem/api_docs/formatters/open_api_specification/version_2/field_definitions/response_field_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          module FieldDefinitions
            class EndpointParamFormatter < ResponseFieldFormatter
              def initialize(endpoint, param_name, param_tree)
                @endpoint = endpoint
                @param_name = param_name
                @param_tree = param_tree
              end

              def format_object_field(field_config, field_properties, include_description = true)
                super(field_config, field_properties, include_description).tap do |field_schema|
                  if (required_props = required_properties(field_properties)).present?
                    field_schema[:required] = required_props
                  end
                end
              end

              def required_properties(field_properties)
                field_properties.select { |_, property_data| property_data[:_config][:required] }.keys
              end
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:endpoint_param][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::FieldDefinitions::EndpointParamFormatter.method(:call)

