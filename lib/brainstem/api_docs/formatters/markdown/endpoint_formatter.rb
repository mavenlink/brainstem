require 'brainstem/api_docs/formatters/abstract_formatter'
require 'brainstem/api_docs/formatters/markdown/helper'
require 'active_support/core_ext/hash/except'
require 'forwardable'

#
# Responsible for formatting each endpoint.
#
module Brainstem
  module ApiDocs
    module Formatters
      module Markdown
        class EndpointFormatter < AbstractFormatter
          include Helper
          extend Forwardable


          ################################################################################
          # Public API
          ################################################################################


          def initialize(endpoint, options = {})
            self.endpoint = endpoint
            self.output   = ""

            super options
          end


          attr_accessor :endpoint,
                        :output


          def call
            return output if endpoint.nodoc?

            format_title!
            format_description!
            format_endpoint!
            format_params!
            format_presents!

            output
          end


          ################################################################################
          private
          ################################################################################

          delegate :controller => :endpoint


          #
          # Formats the title as given, falling back to the humanized action
          # name.
          #
          def format_title!
            output << md_h4(endpoint.title)
          end


          #
          # Formats the description if given.
          #
          def format_description!
            output << md_p(endpoint.description) unless endpoint.description.empty?
          end


          #
          # Formats the actual URI and stated HTTP methods.
          #
          def format_endpoint!
            http_methods = endpoint.http_methods.map(&:upcase).join(" / ")
            path = endpoint.path.gsub('(.:format)', '.json')
            output << md_code("#{http_methods} #{path}")
          end


          #
          # Formats each parameter.
          #
          def format_params!
            return unless endpoint.root_param_keys.any?

            output << md_h5("Valid Parameters")
            output << md_ul do
              endpoint.root_param_keys.inject("") do |buff, (root_param_name, child_keys)|
                if child_keys.nil?
                  buff += parameter_with_indent_level(
                    root_param_name,
                    endpoint.valid_params[root_param_name],
                    0
                  )
                else
                  text = md_inline_code(root_param_name) + "\n"

                  child_keys.each do |param_name|
                    text += parameter_with_indent_level(
                      param_name,
                      endpoint.valid_params[param_name],
                      1
                    )
                  end

                  buff << md_li(text)
                end

                buff
              end
            end
          end


          #
          # Formats a given parameter with a variable indent level. Useful for
          # indifferently formatting root / nested parameters.
          #
          # @param [String] name the param name
          # @param [Hash] options information pertinent to the param
          # @option [Boolean] options :required
          # @option [Boolean] options :legacy
          # @option [Boolean] options :recursive
          # @option [String,Symbol] options :only Deprecated: use +actions+
          #   block instead
          # @option [String] options :info the doc string for the param
          # @option [String] options :type The type of the field.
          #   e.g. string, integer, boolean, array, hash
          # @option [String] options :item_type The type of the items in the field.
          #   Ideally used when the type of the field is an array or hash.
          # @param [Integer] indent how many levels the output should be
          #   indented from normal
          #
          def parameter_with_indent_level(title, options = {}, indent = 0)
            options = options.dup
            text    = md_inline_code(title)

            text += md_inline_type(options.delete(:type), options.delete(:item_type)) if options.has_key?(:type)
            text += " - #{options.delete(:info)}" if options.has_key?(:info)

            if options.keys.any?
              text += "\n"
              text += md_li("Required: #{options[:required].to_s}",   indent + 1) if options.has_key?(:required) && options[:required]
              text += md_li("Legacy: #{options[:legacy].to_s}",       indent + 1) if options.has_key?(:legacy)
              text += md_li("Recursive: #{options[:recursive].to_s}", indent + 1) if options.has_key?(:recursive)
              text.chomp!
            end

            md_li(text, indent)
          end


          #
          # Formats the data model for the action.
          #
          def format_presents!
            if endpoint.presenter
              output << md_h5("Data Model")

              link = md_a(endpoint.presenter_title, endpoint.relative_presenter_path_from_controller(:markdown))
              output << md_ul do
                md_li(link)
              end
            end
          end
        end
      end
    end
  end
end


Brainstem::ApiDocs::FORMATTERS[:endpoint][:markdown] = \
  Brainstem::ApiDocs::Formatters::Markdown::EndpointFormatter.method(:call)
