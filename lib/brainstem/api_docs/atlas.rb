require 'brainstem/api_docs/exceptions'
require 'brainstem/api_docs/endpoint_collection'
require 'brainstem/api_docs/controller_collection'
require 'brainstem/api_docs/presenter_collection'
require 'brainstem/concerns/optional'

#
#
# The Atlas is an object that makes the information from an introspector
# available in formatted and raw format.
#
module Brainstem
  module ApiDocs
    class Atlas
      include Concerns::Optional


      def initialize(introspector, options = {})
        self.endpoints          = EndpointCollection.new
        self.controllers        = ControllerCollection.new
        self.presenters         = ::Brainstem::ApiDocs::PresenterCollection.new

        self.controller_matches = []
        self.introspector       = introspector

        super options

        parse_routes!
        extract_presenters!
        validate!
      end


      attr_accessor :endpoints,
                    :controllers,
                    :presenters


      #########################################################################
      private
      #########################################################################


      #
      # Lists valid options that may be passed on instantiation.
      #
      def valid_options
        super | [ :controller_matches ]
      end


      #
      # Ensures the atlas is valid before allowing consumers to make requests
      # of it.
      #
      def validate!
        raise InvalidAtlasError, "Atlas is not valid." unless valid?
      end


      #
      # Set and read the introspector.
      #
      attr_accessor :introspector


      #
      # Holds +Regexp+s which each controller name must match in order to be
      # included in the list of endpoints.
      #
      attr_accessor :controller_matches


      #
      # Returns a list of all routes that pass the user's filtering.
      #
      def allowed_routes
        introspector.routes.keep_if(&method(:allow_route?))
      end


      #
      # Constructs +Endpoint+ and +Controller wrappers per route.
      #
      def parse_routes!
        allowed_routes.each do |route|
          if (endpoint = endpoints.find_from_route(route))
            endpoint.merge_http_methods!(route[:http_methods])
          else
            controller  = controllers.find_or_create_from_route(route)
            endpoint    = endpoints.create_from_route(route, controller)

            controller.add_endpoint(endpoint)
          end
        end
      end


      #
      # Extracts declared presents for each endpoint and converts it into a
      # Presenter wrapper object.
      #
      def extract_presenters!
        endpoints.with_declared_presents.each do |endpoint|
          presenter = presenters.find_or_create_from_presents(endpoint.declared_presents)
          endpoint.presenter = presenter
        end
      end


      #
      # Whether this Atlas is valid (i.e. if it has at least one endpoint).
      #
      # @return [Boolean] if the atlas is valid
      #
      def valid?
        endpoints.count > 0
      end


      #
      # Returns whether a route's controller passes the limiting regexp passed to the
      # generation command.
      #
      def allow_route?(route)
        introspector.controllers.include?(route[:controller]) &&
          controller_matches.all? { |regexp| route[:controller].to_s =~ regexp }
      end
    end
  end
end
