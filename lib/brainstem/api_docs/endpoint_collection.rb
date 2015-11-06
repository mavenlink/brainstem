require 'brainstem/api_docs/abstract_collection'
require 'brainstem/api_docs/endpoint'
require 'brainstem/concerns/formattable'

module Brainstem
  module ApiDocs
    class EndpointCollection < AbstractCollection
      include Concerns::Formattable


      def find_from_route(route)
        find do |endpoint|
          endpoint.path == route[:path] &&
            endpoint.controller.const == route[:controller] &&
            endpoint.action == route[:action]
        end
      end

      alias_method :find_by_route, :find_from_route


      def create_from_route(route, controller)
        Endpoint.new do |ep|
          ep.path             = route[:path]
          ep.http_methods     = route[:http_methods]
          ep.controller       = controller
          ep.controller_name  = route[:controller_name]
          ep.action           = route[:action]
        end.tap { |endpoint| self.<< endpoint }
      end


      def only_documentable
        self.class.with_members(reject(&:nodoc?))
      end


      def with_declared_presents
        self.class.with_members(reject { |m| m.declared_presents.nil? })
      end


      def sorted
        self.class.with_members(sort)
      end



    end
  end
end
