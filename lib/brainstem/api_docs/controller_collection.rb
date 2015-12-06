require 'brainstem/api_docs/abstract_collection'
require 'brainstem/api_docs/controller'

module Brainstem
  module ApiDocs
    class ControllerCollection < AbstractCollection


      #
      # Creates a new controller from a route object and appends it to the
      # collection.
      def create_from_route(route)
        Controller.new(
          const:  route[:controller],
          name:   route[:controller_name]
        ).tap { |controller| self.<< controller }
      end


      #
      # Finds a controller from a route object.
      #
      def find_by_route(route)
        find do |controller|
          controller.const == route[:controller]
        end
      end


      #
      # Returns a list of unique declared presenters / data models across all
      # controllers.
      #
      def unique_presents
        map do |c|
          c.configuration.keys # For all action contexts + default
            .map { |key| c.configuration[key][:presents].to_s } # Get presents name
        end
          .flatten
          .reject { |presents| presents.nil? || presents.empty? }
          .uniq
          .sort
      end


      #
      # Finds a controller from a route object or creates one if it does not
      # exist.
      #
      def find_or_create_from_route(route)
        find_by_route(route) || create_from_route(route)
      end
      alias_method :find_or_create_by_route, :find_or_create_from_route
    end
  end
end
