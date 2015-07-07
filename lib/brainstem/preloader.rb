module Brainstem
  # Takes a list of arbitrarily nested objects, compacts them, de-duplicates
  # them, and passes them to ActiveRecord to preload.
  #
  # The following is considered a valid data structure:
  #
  #     [:workspaces, {"workspaces" => [:projects], "users" }
  #
  # Which will produce the following for ActiveRecord:
  #
  #     {"workspaces" => [:projects], "users" => []}
  #
  class Preloader

    ################################################################################
    # Class API
    ################################################################################
    class << self
      def preload(*args)
        new(*args).call
      end
    end

    ################################################################################
    # Instance API
    ################################################################################
    attr_accessor :models,
                  :preloads,
                  :reflections,
                  :valid_preloads

    private :valid_preloads=

    attr_writer   :preload_method

    def initialize(models, preloads, reflections, preload_method = nil)
      self.models         = models
      self.preloads       = preloads.compact
      self.reflections    = reflections
      self.preload_method = preload_method
      self.valid_preloads = {}
    end

    def call
      clean!
      preload!
    end

    ################################################################################
    private
    ################################################################################

    # De-duplicates, reformats, and prunes requested preloads into an acceptable
    # format for the preloader
    def clean!
      dedupe!
      remove_unreflected_preloads!
    end

    def preload!
      preload_method.call(models, valid_preloads) if valid_preloads.keys.any?
    end

    # Returns a proc that takes two arguments, +models+ and +association_names+,
    # which, when called, preloads those.
    #
    # @return [Proc] A callable proc
    def preload_method
      @preload_method ||= begin
        if Gem.loaded_specs['activerecord'].version >= Gem::Version.create('4.1')
          ActiveRecord::Associations::Preloader.new.method(:preload)
        else
          Proc.new do |models, association_names|
            ActiveRecord::Associations::Preloader.new(models, association_names).run
          end
        end
      end
    end

    def dedupe!
      preloads.each do |preload_name|
        case preload_name
        when Hash
          preload_name.each do |key, value|
            (valid_preloads[key.to_s] ||= Array.new) << value
          end
        when NilClass
        else
          valid_preloads[preload_name.to_s] ||= []
        end
      end
    end

    def remove_unreflected_preloads!
      valid_preloads.select! { |preload_name, _| reflections.has_key?(preload_name.to_s) }
    end
  end
end
