module Brainstem
  module ApiDocs
    module Introspectors
      class AbstractIntrospector

        # Returns a new instance of the introspector with the environment
        # loaded, ready for introspection.
        #
        # @param [Hash] options arguments to pass on to the instance
        # @return [AbstractIntrospector] the loaded instance
        def self.with_loaded_environment(options = {})
          new(options).tap(&:load_environment!)
        end


        # Override to return a collection of all controller classes.
        #
        # @return [Array<Class>] all controller classes to document
        def controllers
          raise NotImplementedError
        end


        # Override to return a collection of all presenter classes.
        #
        # @return [Array<Class>] all presenter classes to document
        def presenters
          raise NotImplementedError
        end


        # Override to return a collection of hashes with the minimum following
        # keys:
        #
        #     +:path+ - the relative path (i.e. the endpoint)
        #     +:controller+ - the managing controller
        #     +:action+ - the managing action
        #     +:http_method+ - an array of the HTTP methods this route is available on.
        #
        def routes
          raise NotImplementedError
        end


        # Provides both a sanity check to ensure that output confirms to
        # interface and also confirms that there is actually something to
        # generate docs for.
        #
        # @return [Boolean] Whether the Introspector is valid
        def valid?
          valid_controllers? && valid_presenters? && valid_routes?
        end


        #######################################################################
        private
        #######################################################################

        # Don't allow instantiation through 'new'. We want to ensure that
        # instantiation happens through +with_loaded_environment.
        private_class_method :new

        # @api private
        def initialize(options = {})
          options.each { |k, v| self.send("#{k}=", v) }
        end


        # Loads the host application environment.
        # @api private
        def load_environment!
          raise NotImplementedError
        end


        def valid_controllers?
          controllers.is_a?(Array) &&
            controllers.count > 0 &&
            controllers.all? {|c| c.class == Class }
        end

        def valid_presenters?
          presenters.is_a?(Array) &&
            presenters.all? {|p| p.class == Class }
        end

        def valid_routes?
          routes.is_a?(Array) &&
            routes.count > 0 &&
            routes.all? do |r|
              # TODO: This is probably a pretty good sign we should extract
              # here.
              r.is_a?(Hash) &&
                ([:path, :controller, :action, :http_methods] - r.keys).empty?
            end
        end
      end
    end
  end
end
