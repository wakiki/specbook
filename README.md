# Specbook

**Storybook for your Rails specs. Record. Replay. Review.**

Specbook is a Rails engine that turns your RSpec system specs and Turnip features into a browsable, animated walkthrough — screenshots with element overlays, Gherkin step cards with syntax-highlighted Ruby source, and a Playwright trace viewer launcher.

## Why

Reading test output is fine for CI. But when you want to:

- Show a designer what the new flow actually looks like
- Onboard a new dev to the codebase by showing what the specs cover
- Debug a flaky test by replaying the screenshot timeline
- Demo to a stakeholder what's been built without spinning up the app

…you want a viewer, not a log file.

## Install

```ruby
# Gemfile
group :development, :test do
  gem "specbook"
end
```

```bash
bundle install
```

Mount the engine in `config/routes.rb`:

```ruby
mount Specbook::Engine => "/specs"
```

Configure in `config/initializers/specbook.rb`:

```ruby
Specbook.configure do |config|
  # Authorize who can view the player. Default: dev/test only.
  config.authorize_with = ->(controller) { controller.current_user&.admin? }

  # Optional: a "back" link in the top bar.
  config.back_link = { href: "/admin", text: "← Back to admin" }

  # Optional: VS Code link base for jumping to spec source.
  config.editor_base = "vscode://file#{Rails.root}"

  # Optional: per-actor colors for visual differentiation in the viewer.
  config.actor_colors = { "Alice" => "#3b82f6", "Bob" => "#f59e0b" }

  # Optional: directory groupings for the sidebar.
  config.ui_domains = %w[admin public mobile]
end
```

Add the recorder hooks to `spec/rails_helper.rb`:

```ruby
require "specbook/rspec"
```

## Record specs

Run your system specs with `RECORD_SPECS=1` to capture screenshots:

```bash
CI=1 RECORD_SPECS=1 bundle exec rspec spec/system/
```

For Playwright traces:

```bash
RECORD_TRACES=1 bundle exec rspec spec/system/
```

Visit your mount point (e.g. `/specs`) to view.

## Configuration

| Option | Type | Default | Purpose |
|---|---|---|---|
| `authorize_with` | Proc | dev/test only | Lambda receiving the controller; return truthy to allow access |
| `screenshot_root` | Pathname | `Rails.root.join("tmp/spec_screenshots")` | Where screenshots + manifest land |
| `trace_root` | Pathname | `Rails.root.join("tmp/spec_traces")` | Where Playwright traces land |
| `feature_root` | Pathname | `Rails.root` | Project root for resolving `.feature` paths in the manifest |
| `max_runs` | Integer | 20 | Number of historical runs kept |
| `trace_viewer_port` | Integer | 9322 | Port for Playwright trace server |
| `actor_colors` | Hash | `{}` | Name → hex color for spec actors |
| `ui_domains` | Array | `[]` | Top-level sidebar groupings |
| `setup_overlay_rules` | Array | login/exists/redirect | Pattern → icon for non-screenshot steps |
| `back_link` | Hash | `nil` | `{ href:, text: }` — top-bar back link |
| `editor_base` | String | `nil` | URL prefix for opening files in editor (e.g. `"vscode://file/path"`) |

## Compatibility

- Rails 7.1+
- RSpec + Capybara
- Turnip (optional but supported)
- Capybara drivers: Selenium and Playwright tested

## License

MIT — see [LICENSE.txt](LICENSE.txt).
