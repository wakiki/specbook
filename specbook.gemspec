$:.push File.expand_path("lib", __dir__)

require "specbook/version"

Gem::Specification.new do |spec|
  spec.name        = "specbook"
  spec.version     = Specbook::VERSION
  spec.authors     = ["Steve Leung"]
  spec.email       = ["steve@leungs.me"]
  spec.summary     = "Storybook for your Rails specs. Record. Replay. Review."
  spec.description = "Specbook is a Rails engine that turns Turnip features and RSpec system specs into a browsable, animated walkthrough — screenshots with element overlays, Gherkin step cards, and Playwright trace viewer."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/wakiki/specbook"

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.metadata = {
    "homepage_uri"      => spec.homepage,
    "source_code_uri"   => spec.homepage,
    "changelog_uri"     => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri"   => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "rails", ">= 7.1", "< 9"

  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "turnip"
  spec.add_development_dependency "rack-test"
end
