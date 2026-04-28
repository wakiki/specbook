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
  spec.homepage    = "https://github.com/steveh/specbook"

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE", "README.md"]

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "rails", ">= 7.1"

  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "turnip"
end
