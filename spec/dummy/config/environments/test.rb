require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes = true
  config.eager_load = false
  config.public_file_server.enabled = true
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.action_dispatch.show_exceptions = :rescuable if config.action_dispatch.respond_to?(:show_exceptions=)
  config.action_controller.allow_forgery_protection = false
  config.active_support.deprecation = :stderr
  config.logger = Logger.new(IO::NULL)
end
