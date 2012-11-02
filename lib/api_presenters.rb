require "api_presenters/version"
require "api_presenters/base"
require "api_presenters/presenter_collection"

module ApiPresenters
  def self.presenter_collection
    @presenter_collection ||= PresenterCollection.new
  end
end
