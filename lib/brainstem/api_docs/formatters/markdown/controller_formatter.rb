require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/markdown/helper'

module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        class ControllerFormatter < AbstractFormatter
          include Helper

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

          alias_method :include_actions?, :include_actions


          def initialize(controller, options = {})
            self.controller      = controller
            self.output          = ""
            self.include_actions = false
            super options
          end


          def call
            return output if controller.nodoc?
            format_title!
            format_description!
            format_actions!
          end


          #####################################################################
          private
          #####################################################################


          def format_title!
            output << md_h2(controller.title)
          end


          def format_description!
            output << md_p(controller.description) unless controller.description.empty?
          end


          def format_actions!
            return unless include_actions?

            output << md_h3("Endpoints")

            # TODO: Stop this egregious abuse of Demeter and create a
            # +controller.sorted_endpoints+ method.
            output << controller.endpoints
              .sorted
              .formatted_as(:markdown, zero_text: "No endpoints were found.")
          end

        end
      end
    end
  end
end


Brainstem::ApiDocs::FORMATTERS[:controller][:markdown] = \
  Brainstem::ApiDocs::Formatters::Markdown::ControllerFormatter.method(:call)
