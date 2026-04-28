# Opt-in entrypoint for the Specbook recorders.
# Host loads via: require "specbook/rspec"
#
# Honors the same env-var contract as the original support files —
# the recorder bodies are wrapped in `if ENV["RECORD_SPECS"]` /
# `if ENV["RECORD_TRACES"]` so requiring without the env vars set is a no-op.
#
# NOTE: We intentionally do NOT define a `Specbook::RSpec` module here. Doing
# so would shadow the top-level `::RSpec` constant inside any code nested
# under `module Specbook`, breaking references like `RSpec::Core::ExampleGroup`
# in the recorder. The file path `specbook/rspec.rb` is the public name of
# this entrypoint, but it does not expose a corresponding namespace.

require "specbook/recorders/screenshot" if ENV["RECORD_SPECS"]
require "specbook/recorders/playwright_trace" if ENV["RECORD_TRACES"]
