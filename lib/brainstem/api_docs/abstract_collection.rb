require 'brainstem/concerns/optional'
require 'brainstem/concerns/formattable'

module Brainstem
  module ApiDocs
    class AbstractCollection
      include Enumerable
      include Concerns::Optional
      include Concerns::Formattable

      #
      # Creates a new collection with all passed members. Very handy for
      # reduce operations which should return a subset of members but retain
      # the same utility.
      #
      def self.with_members(*members)
        new.tap {|n| members.flatten.each { |m| n << m } }
      end


      def initialize(options = {})
        self.members = []
        super options
      end


      #
      # Handy accessor for extracting the last member of the collection.
      #
      def last
        members[-1]
      end


      #
      # Appends a pre-existing object to the collection.
      #
      def <<(object)
        members << object
      end


      #
      # Iterates over each controller in the collection.
      #
      def each(&block)
        members.each(&block)
      end


      #
      # Returns a map of each member formatted as specified.
      #
      def formatted(format, options = {})
        map { |member| member.formatted_as(format, options) }
      end


      #
      # Returns a map of each formatted member and its suggested filename.
      #
      def formatted_with_filename(format, options = {})
        map {|member| [ member.formatted_as(format, options), member.suggested_filename(format) ] }
      end


      def each_formatted_with_filename(format, options = {}, &block)
        formatted_with_filename(format, options)
          .each { |args| block.call(*args) }
      end


      def each_formatted(format, options = {}, &block)
        formatted(format, options)
          .each { |args| block.call(*args) }
      end



      #########################################################################
      protected
      #########################################################################

      attr_accessor :members
    end
  end
end
