module Specbook
  class Configuration
    attr_accessor :max_runs,
                  :trace_viewer_port,
                  :actor_colors,
                  :ui_domains,
                  :setup_overlay_rules,
                  :back_link,
                  :editor_base,
                  :authorize_with

    attr_writer :screenshot_root, :trace_root, :feature_root

    def initialize
      @max_runs            = 20
      @trace_viewer_port   = 9322
      @actor_colors        = {}
      @ui_domains          = []
      @setup_overlay_rules = [
        { pattern: /\b(?:logs in|signs in|signed in)\b/i, icon: "🔑", note: "Authentication — switching user session" },
        { pattern: /\bexists?\b/i,                        icon: "🔧", note: "Test setup — creating test data" },
        { pattern: /\bredirected to\b/i,                  icon: "✅", note: "Assertion passed — verified redirect" }
      ]
      @back_link       = nil
      @editor_base     = nil
      @authorize_with  = nil
      @screenshot_root = nil
      @trace_root      = nil
      @feature_root    = nil
    end

    def screenshot_root
      @screenshot_root || rails_root.join("tmp/spec_screenshots")
    end

    def trace_root
      @trace_root || rails_root.join("tmp/spec_traces")
    end

    def feature_root
      @feature_root || rails_root
    end

    private

    def rails_root
      defined?(Rails) ? Rails.root : Pathname.new(Dir.pwd)
    end
  end
end
