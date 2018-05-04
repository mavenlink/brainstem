FakeRailsApplication      = Struct.new(:eager_load!, :routes)
FakeRailsRoutesObject     = Struct.new(:routes)
FakeRailsRoutePathObject  = Struct.new(:spec)
FakeRailsRoute            = Struct.new(:name, :path, :defaults, :constraints)
