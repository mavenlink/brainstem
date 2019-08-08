# This is a dummy file which is used in the Introspector specs to simulate a
# loaded rails app.
silence_warnings do
  FakeRailsApplication      = Struct.new(:eager_load!, :routes)
  FakeRailsRoutesObject     = Struct.new(:routes)
  FakeRailsRoutePathObject  = Struct.new(:spec)
  FakeRailsRoute            = Struct.new(:name, :path, :defaults, :verb)
end

class Rails
  def self.application
    @application ||= begin
      #
      # For Rails 4.1 & 4.2, the `verb` method on a route returns a regular expression.
      #
      route_1 = FakeRailsRoute.new(
        "fake_descendant",
        FakeRailsRoutePathObject.new(spec: '/fake_descendant'),
        { controller: "fake_descendant", action: "show" },
        /^GET|POST$/
      )

      route_2 = FakeRailsRoute.new(
        "route_with_no_controller",
        FakeRailsRoutePathObject.new(spec: '/fake_descendant'),
        { },
        /^PATCH$/
      )

      #
      # For Rails 5.x, the `verb` method on a route returns a string.
      #
      route_3 = FakeRailsRoute.new(
        "route_with_invalid_controller",
        FakeRailsRoutePathObject.new(spec: '/fake_descendant'),
        { controller: "invalid_controller", action: "show" },
        'GET'
      )

      route_4 = FakeRailsRoute.new(
        "another_fake_descendant",
        FakeRailsRoutePathObject.new(spec: '/another_fake_descendant'),
        { controller: "another_fake_descendant", action: "update" },
        'PUT|PATCH'
      )

      routes = FakeRailsRoutesObject.new([ route_1, route_2, route_3, route_4 ])

      FakeRailsApplication.new(true, routes)
    end
  end
end

class FakeBasePresenter; end
class FakeDescendantPresenter < FakeBasePresenter; end

class FakeBaseController; end
class FakeDescendantController < FakeBaseController; end

class FakeNonDescendantController; end

class FakeApiEngine
  def self.eager_load!;end
  def self.routes
    @routes ||= begin
      route_1 = FakeRailsRoute.new(
        "fake_descendant",
        FakeRailsRoutePathObject.new(spec: '/fake_route_1'),
        { controller: "fake_descendant", action: "show" },
        /^PUT|PATCH$/
      )

      route_2 = FakeRailsRoute.new(
        "fake_descendant",
        FakeRailsRoutePathObject.new(spec: '/fake_route_2'),
        { controller: "fake_descendant", action: "show" },
        'PUT|PATCH'
      )

      FakeRailsRoutesObject.new([ route_1, route_2 ])
    end
  end
end
