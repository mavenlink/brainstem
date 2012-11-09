require 'active_record'
require 'rspec'
require 'rr'
require 'sqlite3'
require 'database_cleaner'

DatabaseCleaner.strategy = :transaction

#$: << File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'api_presenter'

require_relative 'spec_helpers/db'

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
