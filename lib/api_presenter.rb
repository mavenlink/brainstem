require "api_presenter/version"
require "api_presenter/base"
require "api_presenter/presenter_collection"
require "api_presenter/controller_methods"

module ApiPresenter
  extend self

  attr_writer :default_namespace

  def self.default_namespace
    @default_namespace || "none"
  end

  def presenter_collection(namespace = default_namespace)
    @presenter_collection ||= {}
    @presenter_collection[namespace.to_s.downcase] ||= PresenterCollection.new
  end

  def add_presenter_class(presenter_class, *klasses)
    presenter_collection(namespace_of(presenter_class)).add_presenter_class(presenter_class, *klasses)
  end

  def namespace_of(klass)
    names = klass.to_s.split("::")
    names[-2] ? names[-2] : default_namespace
  end

  def logger
    @logger ||= begin
      if defined?(Rails)
        Rails.logger
      else
        require "logger"
        Logger.new(STDOUT)
      end
    end
  end
end
