require 'brainstem/api_docs/formatters/abstract_formatter'

module Brainstem
  module ApiDocs
    module Formatters
      module OpenApiSpecification
        module Version2
          class ControllerFormatter < AbstractFormatter

            #
            # Declares the options that are permissable to set on this instance.
            #
            def valid_options
              super | [
                :include_actions
              ]
            end

            attr_accessor :controller,
                          :include_actions,
                          :output

            alias_method :include_actions?,
                         :include_actions

            def initialize(controller, options = {})
              self.controller      = controller
              self.output          = {}
              self.include_actions = true

              super options
            end

            def call
              return {} if controller.nodoc?

              format_actions!
            end

            #####################################################################
            private
            #####################################################################

            def format_actions!
              return unless include_actions?

              controller.valid_sorted_endpoints.formatted_as(:oas_v2)
            end
          end
        end
      end
    end
  end
end

Brainstem::ApiDocs::FORMATTERS[:controller][:oas_v2] = \
  Brainstem::ApiDocs::Formatters::OpenApiSpecification::Version2::ControllerFormatter.method(:call)
