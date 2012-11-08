require 'rspec'
require 'rr'

#$: << File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'api_presenter'

RSpec.configure do |config|
  config.mock_with :rr

  config.after(:each) do
    ApiPresenter.clear_collections!
    ApiPresenter.default_namespace = nil
  end
end
