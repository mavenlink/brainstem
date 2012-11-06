require "api_presenter/base"
require "api_presenter/helper"
require "api_presenter/presenter_collection"
require "api_presenter/version"

module ApiPresenter
  extend self

  def presenter_collection
    @presenter_collection ||= PresenterCollection.new
  end

  def presenters
    @presenters ||= {}
  end

  attr_writer :default_namespace

  def self.default_namespace
    @default_namespace || "none"
  end

  def for(klass, namespace = default_namespace)
    presenters[namespace.to_s][klass.to_s] || begin
      raise "Unable to find a presenter in namespace #{namespace} for class #{klass}"
    end
  end

end
