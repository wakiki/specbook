module Specbook
  class ViewerController < ApplicationController
    before_action :authenticate_user!, if: :devise_present?
    before_action :require_authorization

    def show
      @manifest = load_manifest
      @traces = load_traces
      @features = load_features
      @specbook_js_config = build_js_config
      render "specbook/viewer/show", layout: false
    end

    def screenshot
      filename = params[:filename]
      return head(:bad_request) unless filename.match?(/\Astep_\d{4}_\d{3}\.png\z/)

      path = screenshot_dir.join(filename)
      return head(:not_found) unless File.exist?(path)

      send_file path, type: "image/png", disposition: "inline"
    end

    def trace
      filename = params[:filename]
      return head(:bad_request) unless filename.match?(/\A[\w\-]+\.zip\z/)

      path = Rails.root.join("tmp/spec_traces", filename)
      return head(:not_found) unless File.exist?(path)

      send_file path, type: "application/zip", disposition: "attachment"
    end

    TRACE_PORT = 9322

    def view_trace
      filename = params[:filename]
      return head(:bad_request) unless filename.match?(/\A[\w\-]+\.zip\z/)

      path = Rails.root.join("tmp/spec_traces", filename)
      return head(:not_found) unless File.exist?(path)

      # Kill any existing trace viewer on this port
      system("lsof -ti:#{TRACE_PORT} | xargs kill -9 2>/dev/null")
      sleep 0.2

      # Launch Playwright trace viewer on fixed port (headless — no browser open)
      spawn(
        "npx playwright show-trace --port #{TRACE_PORT} --host 127.0.0.1 #{path}",
        [:out, :err] => "/dev/null"
      )

      # Wait for server to be ready
      5.times do
        sleep 0.3
        break if port_open?(TRACE_PORT)
      end

      render json: { url: "http://127.0.0.1:#{TRACE_PORT}" }
    end

    private

    def build_js_config
      rules = (Specbook.config.setup_overlay_rules || []).map do |r|
        pattern = r[:pattern]
        if pattern.is_a?(Regexp)
          { pattern: pattern.source,
            flags:   regexp_flags_to_string(pattern),
            icon:    r[:icon],
            note:    r[:note] }
        else
          { pattern: pattern.to_s,
            flags:   r[:flags] || "",
            icon:    r[:icon],
            note:    r[:note] }
        end
      end

      {
        actorColors:       Specbook.config.actor_colors || {},
        uiDomains:         Specbook.config.ui_domains || [],
        setupOverlayRules: rules,
        editorBase:        Specbook.config.editor_base
      }
    end

    def regexp_flags_to_string(regexp)
      opts = regexp.options
      flags = +""
      flags << "i" if (opts & Regexp::IGNORECASE) != 0
      flags << "m" if (opts & Regexp::MULTILINE) != 0
      flags
    end

    def devise_present?
      defined?(Devise) && respond_to?(:authenticate_user!)
    end

    def require_authorization
      allowed = if Specbook.config.authorize_with
                  Specbook.config.authorize_with.call(self)
                else
                  Rails.env.development? || Rails.env.test?
                end
      redirect_to main_app.root_path unless allowed
    end

    def screenshot_dir
      # Use "latest" symlink, fall back to base dir for old-style flat layout
      latest = Rails.root.join("tmp/spec_screenshots/latest")
      File.exist?(latest) ? Pathname.new(File.realpath(latest)) : Rails.root.join("tmp/spec_screenshots")
    end

    def load_manifest
      path = screenshot_dir.join("manifest.json")
      return [] unless File.exist?(path)

      JSON.parse(File.read(path))
    end

    def load_features
      # Find all .feature files referenced in the manifest
      feature_files = @manifest.map { |e| e["file"] }.uniq.select { |f| f.end_with?(".feature") }
      features = {}
      feature_files.each do |rel_path|
        path = Rails.root.join(rel_path)
        next unless File.exist?(path)
        features[rel_path] = parse_feature(File.read(path))
      end
      features
    end

    def parse_feature(content)
      result = { name: "", description: [], background: [], scenarios: [] }
      current = nil # :description, :background, :scenario

      content.each_line do |line|
        stripped = line.rstrip
        if stripped =~ /^\s*Feature:\s*(.+)/
          result[:name] = $1.strip
          current = :description
        elsif stripped =~ /^\s*Background:/
          current = :background
        elsif stripped =~ /^\s*(@\S+.*)/
          # Tag line — store for next scenario
          @pending_tags = $1.strip
        elsif stripped =~ /^\s*Scenario:\s*(.+)/
          scenario = { name: $1.strip, steps: [], tags: @pending_tags }
          @pending_tags = nil
          result[:scenarios] << scenario
          current = :scenario
        elsif current == :description && stripped =~ /^\s+(.+)/
          result[:description] << $1.strip
        elsif current == :background && stripped =~ /^\s+(Given|And|When|Then)\s+(.+)/
          result[:background] << { keyword: $1, text: $2.strip }
        elsif current == :scenario && stripped =~ /^\s+(Given|And|When|Then)\s+(.+)/
          result[:scenarios].last[:steps] << { keyword: $1, text: $2.strip }
        end
      end
      @pending_tags = nil
      result
    end

    def load_traces
      path = Rails.root.join("tmp/spec_traces/manifest.json")
      return [] unless File.exist?(path)

      JSON.parse(File.read(path))
    end

    def port_open?(port)
      Socket.tcp("127.0.0.1", port, connect_timeout: 0.3) { true }
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT
      false
    end
  end
end
