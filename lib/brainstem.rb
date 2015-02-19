require "brainstem/version"
require "brainstem/presenter"
require "brainstem/presenter_collection"
require "brainstem/controller_methods"

# The Brainstem module itself contains a +default_namespace+ class attribute and a few helpers that make managing +PresenterCollections+ and their corresponding namespaces easier.
module Brainstem
  # Sets {default_namespace} to a new value.
  # @param [String] namespace
  # @return [String] the new default namespace
  def self.default_namespace=(namespace)
    @default_namespace = namespace
  end

  # The namespace that will be used by {presenter_collection} and {add_presenter_class} if none is given or implied.
  # @return [String] the default namespace
  def self.default_namespace
    @default_namespace || "none"
  end

  # @param [String] namespace
  # @return [PresenterCollection] the {PresenterCollection} for the given namespace.
  def self.presenter_collection(namespace = nil)
    namespace ||= default_namespace
    @presenter_collection ||= {}
    @presenter_collection[namespace.to_s.downcase] ||= PresenterCollection.new
  end

  # Helper method to quickly add presenter classes that are in a namespace. For example, +add_presenter_class(Api::V1::UserPresenter, "User")+ would add +UserPresenter+ to the PresenterCollection for the +:v1+ namespace as the presenter for the +User+ class.
  # @param [Brainstem::Presenter] presenter_class The presenter class that is being registered.
  # @param [Array<String, Class>] klasses Classes that will be presented by the given presenter.
  def self.add_presenter_class(presenter_class, *klasses)
    presenter_collection(namespace_of(presenter_class)).add_presenter_class(presenter_class, *klasses)
  end

  # @param [Class] klass The Ruby class whose namespace we would like to know.
  # @return [String] The name of the module containing the passed-in class.
  def self.namespace_of(klass)
    names = klass.to_s.split("::")
    names[-2] ? names[-2] : default_namespace
  end

  # @return [Logger] The Brainstem logger. If Rails is loaded, defaults to the Rails logger. If Rails is not loaded, defaults to a STDOUT logger.
  def self.logger
    @logger ||= begin
      if defined?(Rails)
        Rails.logger
      else
        require "logger"
        Logger.new(STDOUT)
      end
    end
  end

  # Sets a new Brainstem logger.
  # @param [Logger] logger A new Brainstem logger.
  # @return [Logger] The new Brainstem logger.
  def self.logger=(logger)
    @logger = logger
  end

  # Reset all PresenterCollection's Presenters, clear the known collections, and reset the default namespace.
  # This is mostly intended for resetting between tests.
  def self.reset!
    if @presenter_collection
      @presenter_collection.each do |namespace, collection|
        collection.presenters.each do |klass, presenter|
          presenter.class.reset! if presenter.class.respond_to?(:reset!)
        end
      end
    end

    @presenter_collection = {}
    @default_namespace = nil
  end
end
