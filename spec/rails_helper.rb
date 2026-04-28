require "spec_helper"

ENV["RAILS_ENV"] ||= "test"

require File.expand_path("dummy/config/environment", __dir__)
abort("Rails should be in test environment") unless Rails.env.test?

require "rspec/rails"

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
