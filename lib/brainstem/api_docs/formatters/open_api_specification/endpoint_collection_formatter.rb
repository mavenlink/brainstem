require 'brainstem/api_docs/formatters/abstract_formatter'

#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class EndpointCollectionFormatter < AbstractFormatter

          #####################################################################
          # Public API
          #####################################################################

          def initialize(endpoint_collection, options = {})
            self.endpoint_collection = endpoint_collection
            self.output              = {}

            super options
          end


          attr_accessor :endpoint_collection,
                        :output


          def call
            format_endpoints!
          end


          #####################################################################
          private
          #####################################################################

          def documentable_endpoints
            endpoint_collection
              .only_documentable
          end


          def format_endpoints!
            documentable_endpoints.each do |endpoint|
              formatted_endpoint = endpoint.formatted_as(:oas)
              next if formatted_endpoint.blank?

              if (common_keys = output.keys & formatted_endpoint.keys).present?
                common_keys.each do |key|
                  output[key].merge!(formatted_endpoint[key])
                end
              else
                output.merge!(formatted_endpoint)
              end
            end

            output
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:endpoint_collection][:oas] = \
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::EndpointCollectionFormatter.method(:call)
