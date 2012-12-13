module ApiPresenter

  # ControllerMethods are intended to be included into controllers that will be handling requests for presented objects. The present method will pass through +params+, so that any allowed includes, filters, sort orders that are requested will be applied to the presented data.
  module ControllerMethods

    # Return a Ruby hash that contains the models that are requested by the params and allowed
    # by the presenter that is given in the parameter +name+.
    #
    # Pass the returned hash to the render method to convert it into a useful format.
    # For example:
    #    render :json => present("post"){ Post.where(:draft => false) }
    # @param (see PresenterCollection#presenting)
    # @option options [String] :namespace ("none") the namespace to be presented from
    # @yield (see PresenterCollection#presenting)
    # @return (see PresenterCollection#presenting)
    def present(name, options = {}, &block)
      ApiPresenter.presenter_collection(options[:namespace]).presenting(name, options.reverse_merge(:params => params), &block)
    end

  end
end