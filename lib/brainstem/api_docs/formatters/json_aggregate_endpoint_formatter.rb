require 'brainstem/api_docs/formatters/abstract_formatter'
require 'json'

# Formats Api Docs as JSON that can then be explored.
module Brainstem
  module ApiDocs
    module Formatters
      class JsonAggregateEndpointFormatter < AbstractFormatter

        def valid_options
          super | [ :pretty ]
        end


        def call(atlas)
          formatting_method.call(atlas.endpoints.map(&:to_h))
        end


        #
        # Dictates which method to use to format the outgoing data.
        #
        def formatting_method
          pretty ? JSON.method(:pretty_generate) : JSON.method(:generate)
        end


        attr_accessor :pretty
      end
    end
  end
end
