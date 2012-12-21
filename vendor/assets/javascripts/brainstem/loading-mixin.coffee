window.Mavenlink ?= {}

Mavenlink.LoadingMixin =
  setLoaded: (state, options) ->
    options = { trigger: true } unless options? && options.trigger? && !options.trigger
    @loaded = state
    @trigger 'loaded', @ if state && options.trigger

  whenLoaded: (func) ->
    if @loaded
      func()
    else
      @bind "loaded", => func()