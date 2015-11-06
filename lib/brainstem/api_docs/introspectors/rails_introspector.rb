require 'brainstem/api_docs/introspectors/abstract_introspector'
require 'brainstem/api_docs/exceptions'

# For 'constantize'
require 'active_support/inflector/methods'

module Brainstem
  module ApiDocs
    module Introspectors
      class RailsIntrospector < AbstractIntrospector

        #
        # Loads ./config/environment.rb (by default) and eager loads all
        # classes (otherwise +#descendants+ returns an empty set).
        #
        def load_environment!
          load rails_environment_file unless env_already_loaded?
          ::Rails.application.eager_load!

          validate!
        rescue LoadError
          raise IncorrectIntrospectorForAppException,
            "Hosting app does not appear to be a Rails app." +
            "You may have to manually specify an Introspector."
        end


        #
        # Returns a list of presenters that descend from the base presenter
        # class.
        #
        # @return [Array<Class>] an array of descendant classes
        #
        def presenters
          base_presenter_class.descendants
        end


        #
        # Returns a list of controllers that descend from the base controller
        # class.
        #
        # @return [Array<Class>] an array of descendant classes
        #
        def controllers
          base_controller_class.descendants
        end


        #
        # Returns an array of hashes describing the endpoints of the
        # application. See +routes_method+ for the keys of those hashes.
        #
        # @see #routes_method
        #
        # @return [Array<Hash>] each route defined on the hosting app
        def routes
          routes_method.call
        end


        #######################################################################
        private
        #######################################################################

        #
        # Used to short-circuit loading if Rails is already loaded, which
        # reduces start-up time substantially.
        #
        # @return [Boolean] whether Rails has already been loaded.
        def env_already_loaded?
          defined? Rails
        end


        # Returns the path of the Rails +config/environment.rb+ file - by
        # default, +#{Dir.pwd}/config/environment.rb+.
        #
        # @return [String] the absolute path of the config/environment.rb file.
        #
        # # TODO: Also allow configurable app directory.
        #
        def rails_environment_file
          @rails_environment_file ||= File.expand_path(
            File.join(Dir.pwd, 'config', 'environment.rb')
          )
        end


        #
        # Allows a custom location to be set for the environment file if - for
        # example - the command were to be called from a cron task that cannot
        # change directory.
        #
        attr_writer :rails_environment_file


        #
        # Returns the name of the base presenter class.
        # @return [Class] the base presenter class
        #
        def base_presenter_class
          (@base_presenter_class ||= "::Brainstem::Presenter").constantize
        end


        #
        # Allows for the specification for an alternate base presenter class
        # if - for example - only documentation of children of MyBasePresenter
        # is desired. Best used through passing an argument to
        # +with_loaded_environment+.
        #
        # This argument accepts a string because most classes will not be
        # defined at the time of passing, and will only be defined after
        # environment load.
        #
        # @param [String] base_presenter_class the class name to use as the base presenter.
        #
        attr_writer :base_presenter_class


        #
        # Returns the name of the base controller class.
        # @return [Class] the base controller class
        #
        def base_controller_class
          (@base_controller_class ||= "::ApplicationController").constantize
        end


        #
        # Allows for the specification for an alternate base controller class
        # if - for example - only documentation of children of ApiController
        # is desired. Best used through passing an argument to
        # +with_loaded_environment+.
        #
        # This argument accepts a string because most classes will not be
        # defined at the time of passing, and will only be defined after
        # environment load.
        #
        #
        # @param [String] klass the class to use as the base controller.
        #
        attr_writer :base_controller_class


        #
        # Returns the proc that is called to format and retrieve routes.
        # The proc's return must be an array of hashes that contains the
        # following keys:
        #
        #     +:path+ - the relative path
        #     +:controller+ - the managing controller as a constant
        #     +:controller_name+ - the internal underscored name of the controller
        #     +:action+ - the managing action
        #     +:http_method+ - an array of the HTTP methods this route is available on.
        #
        def routes_method
          @routes_method ||= Proc.new do
            Rails.application.routes.routes.map do |route|
              next unless route.defaults.has_key?(:controller) &&
                controller_const = "#{route.defaults[:controller]}_controller"
                  .classify
                  .constantize rescue nil

              {
                alias:            route.name,
                path:             route.path.spec.to_s,
                controller_name:  route.defaults[:controller],
                controller:       controller_const,
                action:           route.defaults[:action],
                http_methods:     route.constraints
                  .fetch(:request_method, nil)
                  .inspect
                  .gsub(/[\/\$\^]/, '')
                  .split("|")
              }
            end.compact
          end
        end


        #
        # Allows setting the routes method used to retrieve the routes if - for
        # example - your application needs to retrieve additional data or if it
        # uses an explicit routing table to define documentable endpoints.
        #
        attr_writer :routes_method


        #
        # Throws an error if the introspector did not produce valid results.
        #
        def validate!
          raise InvalidIntrospectorError, "Introspector is not valid." \
            unless valid?
        end
      end
    end
  end
end
