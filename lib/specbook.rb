require "specbook/version"
require "specbook/configuration"
require "specbook/engine"

module Specbook
  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config
  end
end
