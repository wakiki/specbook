require "rails/engine"

module Specbook
  class Engine < ::Rails::Engine
    isolate_namespace Specbook
  end
end
