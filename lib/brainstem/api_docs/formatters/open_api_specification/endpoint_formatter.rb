require 'active_support/core_ext/hash/except'
require 'forwardable'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_params_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_response_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'

#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class EndpointFormatter < AbstractFormatter
          include Helper
          extend Forwardable

          attr_accessor :endpoint,
                        :endpoint_key,
                        :http_method,
                        :output

          def initialize(endpoint, options = {})
            self.endpoint     = endpoint
            self.endpoint_key = formatted_url
            self.http_method  = formatted_http_method
            self.output       = { endpoint_key => { http_method => {} } }.with_indifferent_access

            super options
          end

          def call
            return {} if endpoint.nodoc? || endpoint.presenter.nil?

            format_summary!
            format_description!
            format_parameters!
            format_response!

            output
          end


          ################################################################################
          private
          ################################################################################

          delegate :controller => :endpoint

          #
          # Formats the actual URI
          #
          def formatted_url
            endpoint.path
              .gsub('(.:format)', '')
              .gsub(/(:(?<param>\w+))/, '{\k<param>}')
          end

          #
          # Formats the actual URI
          #
          def formatted_http_method
            endpoint.http_methods.first.downcase
          end

          #
          # Formats the summary as given, falling back to the humanized action
          # name.
          #
          def format_summary!
            output[endpoint_key][http_method].merge! summary: endpoint.title.to_s.strip
          end

          #
          # Formats the description if given.
          #
          # TODO: Maybe add recursive / legacy to the description
          def format_description!
            if endpoint.description.present?
              output[endpoint_key][http_method].merge! description: endpoint.description.strip
            end
          end

          #
          # Formats each parameter.
          #
          def format_parameters!
            output[endpoint_key][http_method].merge! parameters: EndpointParamsFormatter.call(endpoint)
          end

          #
          # Formats the response.
          #
          def format_response!
            output[endpoint_key][http_method].merge! responses: EndpointResponseFormatter.call(endpoint)
          end
        end
      end
    end
  end
end


Brainstem::ApiDocs::FORMATTERS[:endpoint][:oas] = \
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::EndpointFormatter.method(:call)
