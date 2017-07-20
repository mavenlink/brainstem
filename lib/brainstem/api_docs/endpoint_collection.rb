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
        Endpoint.new(atlas) do |ep|
          ep.path             = route[:path]
          ep.http_methods     = route[:http_methods]
          ep.controller       = controller
          ep.controller_name  = route[:controller_name]
          ep.action           = route[:action]
        end.tap { |endpoint| self.<< endpoint }
      end


      def only_documentable
        self.class.with_members(atlas, reject(&:nodoc?))
      end


      def with_declared_presented_class
        self.class.with_members(atlas, reject { |m| m.declared_presented_class.nil? })
      end


      def sorted
        self.class.with_members(atlas, sort)
      end


      def with_actions_in_controller(const)
        self.class.with_members(atlas, reject { |m| !const.method_defined?(m.action) })
      end


      def sorted_with_actions_in_controller(const)
        with_actions_in_controller(const).sorted
      end
    end
  end
end
