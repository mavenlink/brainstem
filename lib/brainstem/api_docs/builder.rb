require 'brainstem/api_docs/introspectors/rails_introspector'
require 'brainstem/api_docs/atlas'
require 'active_support/core_ext/hash/slice'

#
# This class describes the main API surface for generating API documentation.
# The command-line utility provided with Brainstem is basically just a thin
# veneer over top of this class.
#
# You can use this to programmatically generate the API docs, or to browse them
# while inside a REPL.
#
module Brainstem
  module ApiDocs
    class Builder
      include Brainstem::Concerns::Optional


      def valid_options
        [
          :introspector_method,
          :atlas_method,

          :args_for_introspector,
          :args_for_atlas
        ]
      end


      #
      # @param [Hash] options
      # @option options [Proc] :introspector_method Proc of arity one that
      #   returns an Introspector (an object that introspects into
      #   the host application, seeking its routes, controllers, and
      #   presenters).
      # @option options [Hash] :args_for_introspector Additional arguments to
      #   be passed to the introspector on creation.
      # @option options [Hash] :args_for_atlas Additional arguments to be passed
      #   to the atlas on creation.
      # @option options [Proc,Object] :introspector_method A method that
      #   returns an introspector when called.
      # @option options [Proc,Object] :atlas_method A method that returns an Atlas-like
      #   object when called.
      #
      # @see Brainstem::ApiDocs::Introspectors::AbstractIntrospector
      # @see Brainstem::ApiDocs::Introspectors::RailsIntrospector
      #
      def initialize(options = {})
        super

        build_introspector!
        build_atlas!
      end


      #
      # Builds an introspector.
      #
      def build_introspector!
        self.introspector = introspector_method.call(args_for_introspector)
      end


      #
      # Builds an atlas.
      #
      def build_atlas!
        self.atlas = atlas_method.call(introspector, args_for_atlas)
      end


      #
      # Arguments to be passed to the introspector on creation.
      #
      # @see Brainstem::ApiDocs::Introspectors::AbstractIntrospector
      # @see Brainstem::ApiDocs::Introspectors::RailsIntrospector
      #
      def args_for_introspector
        @args_for_introspector ||= {}
      end


      #
      # Allows passing args to the introspector if - for example - you are
      # using a custom base controller class.
      #
      attr_writer :args_for_introspector


      #
      # Arguments to be passed to the atlas on creation.
      #
      # @see Brainstem::ApiDocs::Atlas
      #
      def args_for_atlas
        @args_for_atlas ||= {}
      end


      #
      # Allows passing args to the atlas if - for example - you are
      # specifying match terms for the allowable controller set.
      #
      attr_writer :args_for_atlas


      #
      # A method which returns the introspector which extracts information
      # about the Brainstem-powered API from the host application.
      #
      # Stored as a proc because it's impossible to inject an instantiated
      # object and have it receive args from this class. This is less important
      # in this specific circumstance but is kept for uniformity with
      # +atlas_method+.
      #
      # @return [Proc] a proc of arity 1 which takes an options hash and
      #   returns an introspector
      #
      def introspector_method
        @introspector_method ||=
          Introspectors::RailsIntrospector.method(:with_loaded_environment)
      end


      #
      # Allows setting the introspector_method if - for example - you are using
      # Brainstem on a Sinatra app and you need to customize how lookups for
      # presenters, controllers, and routes are performed.
      #
      attr_writer :introspector_method


      #
      # Holds a reference to the constructed introspector.
      #
      attr_accessor :introspector


      #
      # A proc of arity 1..2 which takes an introspector and optional options,
      # and which returns a new Atlas.
      #
      # Passed an introspector.
      #
      # @return [Proc] a method to return an atlas
      #
      def atlas_method
        @atlas_method ||= Atlas.method(:new)
      end


      #
      # Allows setting the introspector_method if - for example - you are using
      # an alternative formatter and the requisite information is not present
      # in the +Endpoint+ objects.
      #
      attr_writer :atlas_method


      #
      # Holds a reference to the constructed atlas.
      #
      attr_accessor :atlas
    end
  end
end
