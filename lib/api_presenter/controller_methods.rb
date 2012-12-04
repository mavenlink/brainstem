module ApiPresenter
  module ControllerMethods

    # Return a Ruby hash that contains the models that are requested by the params and allowed
    # by the presenter that is given in the parameter :name:.
    # Pass the returned hash to the render method to convert it into a useful output format.
    # For example,
    #    render :json => present("post"){ Post.where(:draft => false) }
    def present(name, options = {}, &block)
      ApiPresenter.presenter_collection(options[:namespace] || :v1).presenting(name, options.reverse_merge(:params => params), &block)
    end

  end
end