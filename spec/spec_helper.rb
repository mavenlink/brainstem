require 'active_record'
require 'database_cleaner'
require 'rr'
require 'rspec'
require 'sqlite3'

DatabaseCleaner.strategy = :transaction

require 'api_presenter'
require_relative 'spec_helpers/db'
require_relative 'spec_helpers/cleanup'

RSpec.configure do |config|
  config.mock_with :rr

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    ApiPresenter.clear_collections!
    ApiPresenter.default_namespace = nil
    DatabaseCleaner.clean
  end
end
