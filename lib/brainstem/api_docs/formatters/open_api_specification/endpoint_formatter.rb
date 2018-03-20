require 'active_support/core_ext/hash/except'
require 'forwardable'
require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_params_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/endpoint_response_formatter'
require 'brainstem/api_docs/formatters/open_api_specification/helper'
require 'brainstem/api_docs/formatters/markdown/helper'

#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        class EndpointFormatter < AbstractFormatter
          include Helper
          include ::Brainstem::ApiDocs::Formatters::Markdown::Helper
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
            description = endpoint.description.to_s.strip
            description += "." if description.present? && !(description =~ /\.\s*\z/)

            if http_method != 'delete' && presenter.valid_associations.present?
              description += format_associations!
            end

            if description.present?
              output[endpoint_key][http_method].merge! description: description
            end
          end

          #
          # Formats each association.
          #
          def format_associations!
            result = md_h5("Associations")
            result << "Association Name | Associated Class | Description\n"
            result << " --------------  |  --------------  |  ----------\n"

            result << presenter.valid_associations.inject("") do |buffer, (_, association)|
              target_class_name = association.target_class.to_s

              desc = association.description.to_s
              if association.options && association.options[:restrict_to_only]
                desc += "." unless desc =~ /\.\s*\z/
                desc += "  Restricted to queries using the #{md_inline_code("only")} parameter."
                desc.strip!
              end

              buffer << md_inline_code(association.name) + " | " + target_class_name + " | " + desc + "\n"
            end

            result << "\n"
            result << "Any of these associations can be included in your request by providing the include param, e.g. `include=association1,association2.`"
            result << "\n"
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
