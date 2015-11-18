require 'active_support/configurable'

module Brainstem
  module ApiDocs
    include ActiveSupport::Configurable

    config_accessor(:base_path) do
      File.expand_path("./brainstem_docs")
    end


    #
    # Defines the naming pattern of each controller documentation file.
    #
    # The following tokens will be substituted:
    #
    # - {{name}} : the underscored name of the controller without 'controller'
    # - {{extension} : the specified file extension
    #
    # @see #output_extension
    #
    config_accessor(:controller_filename_pattern) do
      File.join("controllers", "{{name}}_controller.{{extension}}")
    end


    #
    # Defines the naming pattern of each presenter documentation file.
    #
    # The following tokens will be substituted:
    #
    # - {{name}} : the demodulized underscored name of the presenter
    # - {{extension} : the specified file extension
    #
    # @see #output_extension
    #
    config_accessor(:presenter_filename_pattern) do
      File.join("models", "{{name}}.{{extension}}")
    end


    #
    # Defines the extension that should be used for output files.
    #
    # Excludes the '.'.
    #
    config_accessor(:output_extension) { "markdown" }


    #
    # Defines the class that all presenters should inherit from / be drawn
    # from.
    #
    # Is a string because most relevant classes are not loaded until much
    # later.
    #
    # @see Brainstem::ApiDocs::RailsIntrospector#base_presenter_class=
    #
    config_accessor(:base_presenter_class) do
      "::Brainstem::Presenter"
    end


    #
    # Defines the class that all controllers should inherit from / be drawn
    # from.
    #
    # Is a string because most relevant classes are not loaded until much
    # later.
    #
    # @see Brainstem::ApiDocs::RailsIntrospector#base_presenter_class=
    #
    config_accessor(:base_controller_class) do
      "::ApplicationController"
    end



    FORMATTERS = {

      # Formatter for entire response
      document:    {},

      # Formatters for collections
      controller_collection: {},
      endpoint_collection:   {},
      presenter_collection:  {},

      # Formatters for individual entities
      controller:  {},
      endpoint:    {},
      presenter:   {},

    }
  end
end

formatter_path = File.expand_path('../formatters/**/*.rb', __FILE__)
Dir.glob(formatter_path).each { |f| require f }
