require 'brainstem/api_docs'
require 'active_support/inflector/inflections'


module Brainstem
  module Concerns
    module Formattable
      attr_writer :formatters


      def valid_options
        super | [ :formatters ]
      end


      def formatters
        @formatters ||= ::Brainstem::ApiDocs::FORMATTERS[formatter_type]
      end


      def formatted_as(format, options = {})
        formatters[format].call(self, options)
      end


      #
      # Declares the type of formatter that should be used to format an entity
      # of this class.
      #
      def formatter_type
        self.class.to_s
          .demodulize
          .underscore
          .to_sym
      end
    end
  end
end
