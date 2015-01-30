module Brainstem
  # ControllerMethods are intended to be included into controllers that will be handling requests for presented objects.
  # The present method will pass through +params+, so that any allowed and requested includes, filters, sort orders
  # will be applied to the presented data.
  module ControllerMethods
    # Return a Ruby hash that contains models requested by the user's params and allowed
    # by the +name+ presenter's configuration.
    #
    # Pass the returned hash to the render method to convert it into a useful format.
    # For example:
    #    render :json => present("post"){ Post.where(:draft => false) }
    # @param (see PresenterCollection#presenting)
    # @option options [String] :namespace ("none") the namespace to be presented from
    # @yield (see PresenterCollection#presenting)
    # @return (see PresenterCollection#presenting)
    def present(name, options = {}, &block)
      Brainstem.presenter_collection(options[:namespace]).presenting(name, options.reverse_merge(params: params), &block)
    end

    # Similar to ControllerMethods#present, but always returns all of the given objects, not just those that match any provided
    # filters.
    # @option options [String] :namespace ("none") the namespace to be presented from
    # @option options [Hash]   :key_map a Hash from Class name to json key name, if desired.
    #                           e.g., map 'SystemWidgets' objects to the 'widgets' key in the JSON.  This is
    #                           only required if the name cannot be inferred.
    # @return (see PresenterCollection#presenting)
    def present_object(objects, options = {})
      options.merge!(params: params, apply_default_filters: false)

      if objects.is_a?(ActiveRecord::Relation) || objects.is_a?(Array)
        fail ActiveRecord::RecordNotFound if objects.empty?
        klass = objects.first.class
        ids = objects.map(&:id)
      else
        klass = objects.class
        ids = objects.id
        options[:params][:only] = ids.to_s
      end

      options[:as] = (options[:key_map] || {})[klass.to_s] || klass.table_name
      present(klass, options) { klass.where(id: ids) }
    end
    alias_method :present_objects, :present_object
  end
end
