require 'active_record'
require 'logger'
require 'rr'
require 'rspec'
require 'sqlite3'
require 'database_cleaner'
require 'pry'
require 'pry-nav'

require 'brainstem'
require_relative 'spec_helpers/schema'
require_relative 'spec_helpers/db'
require_relative 'spec_helpers/rr'

DatabaseCleaner.strategy = :transaction

RSpec.configure do |config|
  config.mock_with :rr

  config.before(:each) do
    Brainstem.logger = Logger.new(StringIO.new)
    Brainstem.reset!
    load File.join(File.dirname(__FILE__), 'spec_helpers', 'presenters.rb')
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
