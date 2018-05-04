require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/markdown/helper'

#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        class EndpointCollectionFormatter < AbstractFormatter
          include Helper

          #####################################################################
          # Public API
          #####################################################################

          def initialize(endpoint_collection, options = {})
            self.endpoint_collection = endpoint_collection
            self.output              = ""
            self.zero_text           = "No endpoints were found."

            super options
          end

          attr_accessor :endpoint_collection,
                        :zero_text,
                        :output

          def valid_options
            super | [ :zero_text ]
          end

          def call
            format_endpoints!
            format_zero_text! if output.empty?
            output
          end

          #####################################################################
          private
          #####################################################################

          def all_formatted_endpoints
            endpoint_collection
              .only_documentable
              .formatted(:markdown)
              .reject(&:empty?)
          end

          def format_endpoints!
            output << all_formatted_endpoints.join(md_hr)
          end

          def format_zero_text!
            output << zero_text
          end
        end
      end
    end
  end
end


Brainstem::ApiDocs::FORMATTERS[:endpoint_collection][:markdown] = \
  Brainstem::ApiDocs::Formatters::Markdown::EndpointCollectionFormatter.method(:call)
