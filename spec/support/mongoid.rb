# frozen_string_literal: true
RSpec.configure do |config|
  config.include Mongoid::Matchers

  config.before(:suite) do
    DatabaseCleaner.orm = :mongoid
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) { DatabaseCleaner[:mongoid].start }

  config.after(:each) { DatabaseCleaner[:mongoid].clean }
end
