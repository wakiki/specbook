# Specbook configuration.
#
# Specbook is a viewer + recorder for Rails system specs. See README for full docs.
# All options below are optional — defaults are sensible.
Specbook.configure do |config|
  # Authorization. Default: dev/test environments only. Provide a lambda
  # taking the controller; return truthy to allow access.
  #
  # config.authorize_with = ->(controller) { controller.current_user&.admin? }

  # A "back" link in the top bar. Default: no link.
  #
  # config.back_link = { href: "/admin", text: "← Back to admin" }

  # URL prefix for opening files in your editor. Default: nil (file:line is
  # rendered as plain text).
  #
  # config.editor_base = "vscode://file#{Rails.root}"

  # Per-actor colors for visual differentiation in the viewer.
  #
  # config.actor_colors = {
  #   "Alice" => "#3b82f6",
  #   "Bob"   => "#f59e0b"
  # }

  # Top-level directory groupings for the sidebar.
  #
  # config.ui_domains = %w[admin public mobile]

  # Pattern → icon mapping for non-screenshot Gherkin steps. Defaults provide
  # generic login/setup/redirect rules; add domain-specific rules here.
  #
  # config.setup_overlay_rules = [
  #   { pattern: /booking exists/i, icon: "📅", note: "Test setup" }
  # ] + Specbook::Configuration.new.setup_overlay_rules

  # Where artifacts are written. Defaults below match Rails.root paths.
  #
  # config.screenshot_root = Rails.root.join("tmp/spec_screenshots")
  # config.trace_root      = Rails.root.join("tmp/spec_traces")
  # config.feature_root    = Rails.root
  # config.max_runs           = 20
  # config.trace_viewer_port  = 9322
end
