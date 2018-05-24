require 'active_support/core_ext/hash/except'
require 'forwardable'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/endpoint/param_definitions_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/version_2/endpoint/response_definitions_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          class EndpointFormatter < AbstractFormatter
            include Helper
            extend Forwardable

            attr_accessor :endpoint,
                          :presenter,
                          :endpoint_key,
                          :http_method,
                          :output

            def initialize(endpoint, options = {})
              self.endpoint     = endpoint
              self.presenter    = endpoint.presenter
              self.endpoint_key = formatted_url
              self.http_method  = format_http_method(endpoint)
              self.output       = { endpoint_key => { http_method => {} } }.with_indifferent_access

              super options
            end

            def call
              return {} if endpoint.nodoc?

              format_summary!
              format_optional_info!
              format_security!
              format_tags!
              format_parameters!
              format_response!

              output
            end

            ################################################################################
            private
            ################################################################################

            delegate :controller => :endpoint

            ################################################################################
            # Methods to override
            ################################################################################

            #
            # Format the endpoint summary
            #
            def summary
              endpoint.title
            end

            #
            # Format the endpoint description
            #
            def description
              endpoint.description
            end

            #
            # Formats the actual URI
            #
            def formatted_url
              endpoint.path
                .gsub('(.:format)', '')
                .gsub(/(:(?<param>\w+))/, '{\k<param>}')
                .gsub(Brainstem::ApiDocs.base_path, '')
            end

            ################################################################################
            # Avoid overridding
            ################################################################################

            #
            # Formats the summary as given, falling back to the humanized action
            # name.
            #
            def format_summary!
              output[endpoint_key][http_method].merge! summary: summary.to_s.strip
            end

            #
            # Adds the following properties.
            #   - description
            #   - operation_id
            #   - consumes
            #   - produces
            #   - schemes
            #   - external_docs
            #   - deprecated
            #
            def format_optional_info!
              info = {
                description:    format_description(description),
                operation_id:   endpoint.operation_id,
                consumes:       endpoint.consumes,
                produces:       endpoint.produces,
                schemes:        endpoint.schemes,
                external_docs:  endpoint.external_docs,
                deprecated:     endpoint.deprecated,
              }.reject { |_,v| v.blank? }

              output[endpoint_key][http_method].merge!(info)
            end

            #
            # Adds the security schemes for the given endpoint.
            #
            def format_security!
              return if endpoint.security.nil?

              output[endpoint_key][http_method].merge! security: endpoint.security
            end

            #
            # Adds the tags for the given endpoint.
            #
            def format_tags!
              tag_name = endpoint.controller.tag || format_tag_name(endpoint.controller.name)

              output[endpoint_key][http_method].merge! tags: [tag_name]
            end

            #
            # Formats each parameter.
            #
            def format_parameters!
              output[endpoint_key][http_method].merge!(
                parameters: ::Brainstem::ApiDocs::FORMATTERS[:parameters][:oas_v2].call(endpoint)
              )
            end

            #
            # Formats the response.
            #
            def format_response!
              output[endpoint_key][http_method].merge!(
                responses: ::Brainstem::ApiDocs::FORMATTERS[:response][:oas_v2].call(endpoint)
              )
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:endpoint][:oas_v2] =
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::EndpointFormatter.method(:call)
