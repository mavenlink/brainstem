#= require ./loading-mixin

class Mavenlink.Collection extends Backbone.Collection
  constructor: ->
    super
    @setLoaded false

  update: (models) ->
    models = models.models if models.models?
    for model in models
      backboneModel = @_prepareModel(model)
      if backboneModel
        if modelInCollection = @get(backboneModel.id)
          modelInCollection.set backboneModel.attributes
        else
          @add backboneModel
      else
        Utils.warn "Unable to update collection with invalid model", model

  ids: => _.keys(@_byId)

  loadNextPage: (options) =>
    oldLength = @length
    success = (collection) =>
      options.success(collection, collection.length == oldLength + @lastFetchOptions.perPage) if options.success?
    base.data.loadCollection @lastFetchOptions.name, _.extend({}, @lastFetchOptions, options, page: @lastFetchOptions.page + 1, collection: this, success: success)

  reload: (options) =>
    base.clearCaches()
    @reset [], silent: true
    @setLoaded false
    base.data.loadCollection @lastFetchOptions.name, _.extend({}, @lastFetchOptions, options, page: 1, collection: this)

  getWithAssocation: (id) =>
    @get(id)

  # Return a function that applies the given filter(s).
  @getFilterer: (filters) ->
    filters ||= []
    filters = [filters] unless filters instanceof Array
    defaults = _(@defaultFilters || []).chain().map((f) -> f.split(":")).inject(((memo, [field, value]) -> memo[field] = value; memo), {}).value()
    filters = _(filters).chain().map((f) -> f.split(":")).inject(((memo, [field, value]) -> memo[field] = value; memo), {}).defaults(defaults).value()
    filterFunctions = (@filters(field, value) for field, value of filters)
    return (model) ->
      for filter in filterFunctions
        return false unless filter(model)
      true

  @filters: (field, value) ->
    if field == "search"
      (model) -> model.matchesSearch(value)
    else
      (model) -> String(model.get(field)) == value

  @getComparatorWithIdFailover: (order) ->
    [field, direction] = order.split(":")
    comp = @getComparator(field)
    (a, b) ->
      [b, a] = [a, b] if direction.toLowerCase() == "desc"
      result = comp(a, b)
      if result == 0
        a.get('id') - b.get('id')
      else
        result

  @getComparator: (field) ->
    return (a, b) -> a.get(field) - b.get(field)

_.extend(Mavenlink.Collection.prototype, Mavenlink.LoadingMixin);