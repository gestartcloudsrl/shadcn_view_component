require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.active_support.deprecation = :log
  config.action_dispatch.verbose_redirect_logs = true
  config.assets.quiet = true

  config.action_view.annotate_rendered_view_with_filenames = false
  config.action_controller.raise_on_missing_callback_actions = true
end
