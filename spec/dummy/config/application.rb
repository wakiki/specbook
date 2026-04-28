require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "specbook"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.consider_all_requests_local = true
    config.hosts.clear if config.respond_to?(:hosts)
    config.secret_key_base = "dummy" * 20
  end
end
