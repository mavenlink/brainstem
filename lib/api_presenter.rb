require "api_presenter/version"
require "api_presenter/base"
require "api_presenter/presenter_collection"

module ApiPresenter
  extend self

  def presenter_collection
    @presenter_collection ||= PresenterCollection.new
  end

  def presenters
    Base.presenters
  end

  def find_presenter(namespace, klass)
    presenters[namespace.to_s][klass.to_s] || begin
      raise "Unable to find a presenter in namespace #{namespace} for class #{klass}"
    end
  end

end
