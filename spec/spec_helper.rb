require "active_record"
require "logger"
require "rr"
require "rspec"
require "sqlite3"

require "brainstem"
require_relative "spec_helpers/db"
require_relative "spec_helpers/cleanup"

RSpec.configure do |config|
  config.mock_with :rr

  config.before(:each) do
    Brainstem.logger = Logger.new(StringIO.new)
  end

  config.after(:each) do
    Brainstem.clear_collections!
    Brainstem.default_namespace = nil
  end
end
