module Specbook
  class Configuration
    attr_accessor :artifact_root,
                  :max_runs,
                  :trace_viewer_port,
                  :actor_colors,
                  :ui_domains,
                  :setup_overlay_rules,
                  :back_link,
                  :editor_base,
                  :authorize_with

    def initialize
      @artifact_root       = nil
      @max_runs            = 20
      @trace_viewer_port   = 9322
      @actor_colors        = {}
      @ui_domains          = []
      @setup_overlay_rules = [
        { pattern: /\b(?:logs in|signs in|signed in)\b/i, icon: "🔑", note: "Authentication — switching user session" },
        { pattern: /\bexists?\b/i,                        icon: "🔧", note: "Test setup — creating test data" },
        { pattern: /\bredirected to\b/i,                  icon: "✅", note: "Assertion passed — verified redirect" }
      ]
      @back_link           = nil
      @editor_base         = nil
      @authorize_with      = nil
    end
  end
end
