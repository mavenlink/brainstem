require "api_presenter/version"
require "api_presenter/base"
require "api_presenter/presenter_collection"

module ApiPresenter
  def self.presenter_collection
    @presenter_collection ||= PresenterCollection.new
  end

  def self.presenters
    Base.presenters
  end
end
