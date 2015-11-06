require 'brainstem/api_docs'
require 'active_support/inflector/inflections'

#
# TODO: Spec this out
#
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
      # # TODO: Switch this to just use 'endpoint_collection', etc. for clxn
      #
      def formatter_type
        self.class.to_s
          .demodulize
          .underscore
          .to_sym
      end


      #
      # Gives a suggested filename for this format.
      #
      # def suggested_filename(format)
      #   raise NotImplementedError
      # end


      #
      # Yields block with entity formatted in requested format and suggested
      # filename. Raises a NotImplementedError if the class is not enumerable.
      #
      # def each_formatted_with_filename(format, options = {}, &block)
      #   raise NotImplementedError unless respond_to?(:map)
      #   map { |entity| [ entity.formatted_as(format, options), entity.suggested_filename(format) ] }
      #     .each { |args| block.call(*args) }
      # end
    end
  end
end
