require 'active_support/configurable'

module Brainstem
  module ApiDocs
    include ActiveSupport::Configurable

    config_accessor(:base_path) do
      File.expand_path("./brainstem_docs")
    end

    config_accessor(:controller_filename_pattern) do
      File.join("controllers", "{{name}}_controller.{{extension}}")
    end

    config_accessor(:presenter_filename_pattern) do
      File.join("models", "{{name}}.{{extension}}")
    end

    config_accessor(:output_extension) { "markdown" }



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
