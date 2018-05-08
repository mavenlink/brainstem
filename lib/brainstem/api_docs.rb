require 'active_support/configurable'

module Brainstem
  module ApiDocs
    include ActiveSupport::Configurable

    config_accessor(:write_path) do
      File.expand_path("./brainstem_docs")
    end

    #
    # Defines the naming pattern of each controller documentation file.
    #
    # The following tokens will be substituted:
    #
    # - {{namespace}} : the namespace of the controller underscored,
    #                   i.e. 'api/v1'
    # - {{name}}      : the underscored name of the controller without
    #                   'controller'
    # - {{extension}  : the specified file extension
    #
    # @see #output_extension
    #
    config_accessor(:controller_filename_pattern) do
      File.join("endpoints", "{{name}}.{{extension}}")
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
      File.join("objects", "{{name}}.{{extension}}")
    end

    #
    # Defines the naming pattern for the relative link to each controller documentation file.
    #
    # The following tokens will be substituted:
    #
    # - {{name}} : the underscored name of the controller without 'controller'
    # - {{extension} : the specified file extension
    #
    # @see #output_extension
    #
    config_accessor(:controller_filename_link_pattern) do
      controller_filename_pattern
    end

    #
    # Defines the naming pattern for the relative link to each presenter documentation file.
    #
    # The following tokens will be substituted:
    #
    # - {{name}} : the demodulized underscored name of the presenter
    # - {{extension} : the specified file extension
    #
    # @see #output_extension
    #
    config_accessor(:presenter_filename_link_pattern) do
      presenter_filename_pattern
    end

    #
    # Defines the base path for the given API.
    #
    config_accessor(:base_path) { "/v2" }

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
    # @see Brainstem::ApiDocs::RailsIntrospector#base_controller_class=
    #
    config_accessor(:base_controller_class) do
      "::ApplicationController"
    end

    #
    # Defines the application or engine that all routes will be fetched from.
    #
    # Is a proc because most relevant classes are not loaded until much
    # later.
    #
    # @see Brainstem::ApiDocs::RailsIntrospector#base_application_proc=
    #
    config_accessor(:base_application_proc) do
      Proc.new { Rails.application }
    end

    #
    # If associations on a presenter have no description, i.e. no documentation,
    # should they be documented anyway?
    #
    config_accessor(:document_empty_presenter_associations) { true }

    #
    # If filters on a presenter have no `:info` key, i.e. no documentation,
    # should they be documented anyway?
    #
    config_accessor(:document_empty_presenter_filters) { true }

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

      # Formatter for Open Api Specifications
      info:       {},
      response:   {},
      parameters: {},
      security:   {},
      tags:       {},
    }
  end
end

formatter_path = File.expand_path('../formatters/**/*.rb', __FILE__)
Dir.glob(formatter_path).each { |f| require f }
