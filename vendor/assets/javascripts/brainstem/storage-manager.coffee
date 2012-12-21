window.App ?= {}

# Todo: Record access timestamps on all Mavenlink.Models by overloading #get and #set.  Keep a sorted list (Heap?) of model references.
#    clean up the oldest ones if memory is low
#    allow passing a recency parameter to the StorageManager

# The StorageManager class is used to manage a set of Mavenlink.Collections.  It is responsible for loading data and
# maintaining caches.
class window.App.StorageManager
  constructor: ->
    @collections = {}

  # Add a collection to the StorageManager.  All collections that will be loaded or used in associations must be added.
  #    manager.addCollection "time_entries", App.Collections.TimeEntries
  addCollection: (name, collectionClass) ->
    @collections[name] =
      klass: collectionClass
      modelKlass: collectionClass.prototype.model
      storage: new collectionClass()
      sortLengths: {}

  # Access the cache for a particular collection.
  #    manager.storage("time_entries").get(12).get("title")
  storage: (name) =>
    @getCollectionDetails(name).storage

  dataUsage: =>
    sum = 0
    for dataType in @collectionNames()
      sum += @storage(dataType).length
    sum

  reset: =>
    for name, attributes of @collections
      attributes.storage.reset []
      attributes.sortLengths = {}

  # Access details of a collection.  An error will be thrown if the collection cannot be found.
  getCollectionDetails: (name) =>
    @collections[name] || @collectionError(name)

  collectionNames: =>
    _.keys(@collections)

  collectionExists: (name) =>
    !!@collections[name]

  # Request a model to be loaded, optionally ensuring that associations be included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     model = manager.loadModel "time_entry"
  #     model = manager.loadModel "time_entry", fields: ["title", "notes"]
  #     model = manager.loadModel "time_entry", include: ["workspace", "story"]
  loadModel: (name, id, options) =>
    options = _.clone(options || {})
    oldSuccess = options.success
    collectionName = name.pluralize()
    model = new (@getCollectionDetails(collectionName).modelKlass)()
    @loadCollection collectionName, _.extend options,
      only: id
      success: (collection) ->
        model.setLoaded true, trigger: false
        model.set collection.get(id).attributes
        model.setLoaded true
        oldSuccess(model) if oldSuccess
    model

  # Request a set of data to be loaded, optionally ensuring that associations be included as well.  A collection is returned immediately and is reset
  # when the load, and any dependent loads, are complete.
  #     collection = manager.loadCollection "time_entries"
  #     collection = manager.loadCollection "time_entries", only: [2, 6]
  #     collection = manager.loadCollection "time_entries", fields: ["title", "notes"]
  #     collection = manager.loadCollection "time_entries", include: ["workspace", "story"]
  #     collection = manager.loadCollection "time_entries", include: ["workspace:title,description", "story:due_date"]
  #     collection = manager.loadCollection "stories",      include: ["assets", { "assignees": "account" }, { "sub_stories": ["assignees", "assets"] }]
  #     collection = manager.loadCollection "time_entries", filters: ["workspace_id:6", "editable:true"], order: "updated_at:desc", page: 1, perPage: 20
  loadCollection: (name, options) =>
    options = $.extend({}, options, name: name)
    @_checkPageSettings options
    @_logDataUsage()
    include = @_wrapObjects(@_extractArray "include", options)

    comparator = @getCollectionDetails(name).klass.getComparatorWithIdFailover(options.order || "updated_at:desc")
    collection = options.collection || @createNewCollection name, [], comparator: comparator
    collection.setLoaded false
    collection.reset([], silent: false) if options.reset
    collection.lastFetchOptions = _.pick($.extend(true, {}, options), 'name', 'fields', 'filters', 'include', 'page', 'perPage', 'order')

    @_loadCollectionWithFirstLayer($.extend({}, options, include: include, success: ((firstLayerCollection) =>
      expectedAdditionalLoads = @_countRequiredServerRequests(include) - 1
      if expectedAdditionalLoads > 0
        timesCalled = 0
        @_handleNextLayer firstLayerCollection, include, =>
          timesCalled += 1
          if timesCalled == expectedAdditionalLoads
            @_success(options, collection, firstLayerCollection)
      else
        @_success(options, collection, firstLayerCollection)
    )))

    collection

  _handleNextLayer: (collection, include, callback) =>
    # Collection is a fully populated collection of stories whose first layer of associations are loaded.
    # include is a hierarchical list of associations on those stories:
    #   [{ 'time_entries': ['workspace': [], 'story': [{ 'assignees': []}]] }, { 'workspace': [] }]

    _(include).each (hash) => # { 'time_entries': ['workspace': [], 'story': [{ 'assignees': []}]] }
      association = _.keys(hash)[0] # time_entries
      nextLevelInclude = hash[association] # ['workspace': [], 'story': [{ 'assignees': []}]]
      if nextLevelInclude.length
        association_ids = _(collection.models).chain().
          map((m) -> if (a = m.get(association)) instanceof Backbone.Collection then a.models else a).
          flatten().uniq().compact().pluck("id").sort().value()
        newCollectionName = collection.model.associationDetails(association).collectionName
        @_loadCollectionWithFirstLayer name: newCollectionName, only: association_ids, include: nextLevelInclude, success: (loadedAssociationCollection) =>
          @_handleNextLayer(loadedAssociationCollection, nextLevelInclude, callback)
          callback()

  _loadCollectionWithFirstLayer: (options) =>
    options = $.extend({}, options)
    name = options.name
    only = if options.only then _.map((@_extractArray "only", options), (id) -> String(id)) else null
    include = _(options.include).map((i) -> _.keys(i)[0]) # pull off the top layer of includes
    fields  = @_extractArray "fields",  options
    filters = @_extractArray "filters", options
    order = options.order || "updated_at:desc"
    cacheKey = order + "|" + _(filters).sort().join(",")

    cachedCollection = @storage name
    comparator = @getCollectionDetails(name).klass.getComparatorWithIdFailover(order)
    collection = @createNewCollection name, [], comparator: comparator

    if only?
      alreadyLoadedIds = _.select only, (id) => cachedCollection.get(id)?.associationsAreLoaded(include)
      if alreadyLoadedIds.length == only.length
        # We've already seen every id that is being asked for and have all the associated data.
        @_success options, collection, _.map only, (id) => cachedCollection.get(id)
        return collection
    else
      # Check if we have, at some point, requested enough records with this this order and filter(s).
      if (@getCollectionDetails(name).sortLengths[cacheKey] || 0) >= options.perPage * options.page
        subset = @orderFilterAndSlice(cachedCollection, comparator, collection, filters, options.page, options.perPage)
        if (_.all(subset, (model) => model.associationsAreLoaded(include)))
          @_success options, collection, subset
          return collection

    if options.page - (@getCollectionDetails(name).sortLengths[cacheKey] / options.perPage) > 1
      Utils.throwError("You cannot request a page of data greater than #{@getCollectionDetails(name).sortLengths[cacheKey] / options.perPage} for this collection.  Please request only sequential pages.")

    # If we haven't returned yet, we need to go to the server to load some missing data.

    syncOptions =
      data: {}
      parse: true
      error: Backbone.wrapError(options.error, collection, options)
      success: (resp, status, xhr) =>
        # The server response should look something like this:
        #  {
        #    time_entries: [{ id: 2, title: "te1", workspace_id: 6, story_id: [10, 11] }]
        #    workspaces: [{id: 6, title: "some workspace", time_entry_ids: [2] }]
        #    stories: [{id: 10, title: "some story" }, {id: 11, title: "some other story" }]
        #  }
        # Loop over all returned data types and update our local storage to represent any new data.
        for underscoredModelName, models of resp
          unless underscoredModelName == 'count'
            @storage(underscoredModelName).update models

        if only?
          @_success options, collection, _.map(only, (id) -> cachedCollection.get(id))
        else
          @getCollectionDetails(name).sortLengths[cacheKey] = options.page * options.perPage
          @_success options, collection, @orderFilterAndSlice(cachedCollection, comparator, collection, filters, options.page, options.perPage)

    syncOptions.data.include = include.join(";") if include.length
    syncOptions.data.only = _.difference(only, alreadyLoadedIds).join(",") if only?
    syncOptions.data.fields = fields.join(",") if fields.length
    syncOptions.data.order = options.order if options.order?
    syncOptions.data.filters = filters.join(",") if filters.length
    syncOptions.data.per_page = options.perPage unless only?
    syncOptions.data.page = options.page unless only?

    Backbone.sync.call collection, 'read', collection, syncOptions

    collection

  _success: (options, collection, data) =>
    if data
      data = data.models if data.models?
      collection.setLoaded true, trigger: false
      if collection.length
        collection.add data
      else
        collection.reset data
    collection.setLoaded true
    options.success(collection) if options.success?

  _checkPageSettings: (options) =>
    options.perPage = options.perPage || 20
    options.perPage = 1 if options.perPage < 1
    options.page = options.page || 1
    options.page = 1 if options.page < 1

  collectionError: (name) =>
    Utils.throwError("Unknown collection #{name} in StorageManager.  Known collections: #{_(@collections).keys().join(", ")}")

  createNewCollection: (collectionName, models = [], options = {}) =>
    loaded = options.loaded
    delete options.loaded
    collection = new (@getCollectionDetails(collectionName).klass)(models, options)
    collection.setLoaded(true, trigger: false) if loaded
    collection

  createNewModel: (modelName, options) =>
    new (@getCollectionDetails(modelName.pluralize()).modelKlass)(options || {})

  orderFilterAndSlice: (collection, comparator, filterCollection, filters, page, perPage) =>
    collection = collection.models if collection.models?
    subset = _(collection).sort(comparator)
    subset = _(subset).filter(filterCollection.constructor.getFilterer(filters))
    sliced = subset.slice((page - 1) * perPage, page * perPage)
    return sliced

  _extractArray: (option, options) =>
    result = options[option]
    result = [result] unless result instanceof Array
    _.compact(result)

  _wrapObjects: (array) =>
    output = []
    _(array).each (elem) =>
      if elem.constructor == Object
        for key, value of elem
          o = {}
          o[key] = @_wrapObjects(if value instanceof Array then value else [value])
          output.push o
      else
        o = {}
        o[elem] = []
        output.push o
    output

  _countRequiredServerRequests: (array, wrapped = false) =>
    if array?.length
      array = @_wrapObjects(array) unless wrapped
      sum = 1
      _(array).each (elem) =>
        sum += @_countRequiredServerRequests(_(elem).values()[0], true)
      sum
    else
      0

  _logDataUsage: =>
    dataUsage = @dataUsage()
    if dataUsage > 500
      bin = Math.round(dataUsage / 100)
      @previouslyLoggedBins ||= []
      unless bin in @previouslyLoggedBins
        Utils.trackPageView("/dataLoaded/#{bin}")
        @previouslyLoggedBins.push bin
