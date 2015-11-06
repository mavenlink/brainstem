# This is a dummy file which is used in the Introspector specs to simulate a
# loaded rails app.
FakeRailsApplication      = Struct.new(:eager_load!, :routes)
FakeRailsRoutesObject     = Struct.new(:routes)
FakeRailsRoutePathObject  = Struct.new(:spec)
FakeRailsRoute            = Struct.new(:name, :path, :defaults, :constraints)


class Rails
  def self.application
    @application ||= begin
      route_1 = FakeRailsRoute.new(
        "fake_descendant",
        FakeRailsRoutePathObject.new(spec: '/fake_descendant'),
        { controller: "fake_descendant", action: "show" },
        { :request_method => /^GET|POST$/ }
      )

      route_2 = FakeRailsRoute.new(
        "route_with_no_controller",
        FakeRailsRoutePathObject.new(spec: '/fake_descendant'),
        { },
        { :request_method => /^PATCH$/ }
      )

      route_3 = FakeRailsRoute.new(
        "route_with_invalid_controller",
        FakeRailsRoutePathObject.new(spec: '/fake_descendant'),
        { controller: "invalid_controller", action: "show" },
        { :request_method => /^GET$/ }
      )

      routes = FakeRailsRoutesObject.new([ route_1, route_2, route_3 ])

      FakeRailsApplication.new(true, routes)
    end
  end
end


class FakeBasePresenter; end
class FakeDescendantPresenter < FakeBasePresenter; end

class FakeBaseController; end
class FakeDescendantController < FakeBaseController; end

class FakeNonDescendantController; end
