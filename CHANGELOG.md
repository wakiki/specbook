# Changelog

All notable changes to Specbook are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-28

First public release.

### Added
- Mountable Rails engine (`mount Specbook::Engine => "/specs"`).
- Screenshot recorder (`RECORD_SPECS=1`) — captures Capybara screenshots + element bounding boxes after each step.
- Playwright trace recorder (`RECORD_TRACES=1`) — captures Playwright traces and serves them via `npx playwright show-trace`.
- Configurable seams: `authorize_with`, `screenshot_root`, `trace_root`, `feature_root`, `actor_colors`, `ui_domains`, `setup_overlay_rules`, `back_link`, `editor_base`, `max_runs`, `trace_viewer_port`.
- Sensible default overlay rules (login → 🔑, exists → 🔧, redirected → ✅).
- Install generator: `rails generate specbook:install`.
- Engine-internal test suite with dummy Rails app at `spec/dummy/`.
- GitHub Actions CI matrix: Ruby 3.1–3.3 × Rails 7.1–8.0.

## [0.1.0.alpha] — 2026-04-25

Internal vendoring milestone; not published.
