# frozen_string_literal: true

# Playwright trace recorder for spec presentations.
# Enable with: RECORD_TRACES=1 CI=1 bundle exec rspec spec/system/
#
# Captures Playwright traces (DOM snapshots, network, console, action timeline)
# for each system spec. View with: npx playwright show-trace tmp/spec_traces/<name>.zip

if ENV["RECORD_TRACES"]
  require "fileutils"

  module Specbook
    module Recorders
      module PlaywrightTrace
        TRACE_DIR = Rails.root.join("tmp/spec_traces")
        mattr_accessor :manifest
        self.manifest = []

        def self.slug_for(example)
          example.full_description
            .gsub(/[^a-zA-Z0-9]+/, "_")
            .gsub(/\A_|_\z/, "")
            .truncate(120, omission: "")
        end

        def self.write_manifest!
          FileUtils.mkdir_p(TRACE_DIR)
          File.write(
            TRACE_DIR.join("manifest.json"),
            JSON.pretty_generate(manifest)
          )
        end
      end

      # Patch visit to start tracing on first navigation
      module TraceVisitPatch
        def visit(path, **)
          if !@_trace_started && page.driver.respond_to?(:with_playwright_page)
            page.driver.with_playwright_page do |pw_page|
              pw_page.context.tracing.start(screenshots: true, snapshots: true, sources: false)
            end
            @_trace_started = true
          end
          super
        end
      end
    end
  end

  RSpec.configure do |config|
    config.include Specbook::Recorders::TraceVisitPatch, type: :system

    config.before(:each, type: :system) do
      @_trace_started = false
    end

    config.after(:each, type: :system) do |example|
      next unless @_trace_started
      next unless page.driver.respond_to?(:with_playwright_page)

      slug = Specbook::Recorders::PlaywrightTrace.slug_for(example)
      filename = "#{slug}.zip"
      filepath = Specbook::Recorders::PlaywrightTrace::TRACE_DIR.join(filename)
      FileUtils.mkdir_p(Specbook::Recorders::PlaywrightTrace::TRACE_DIR)

      begin
        page.driver.with_playwright_page do |pw_page|
          pw_page.context.tracing.stop(path: filepath.to_s)
        end

        Specbook::Recorders::PlaywrightTrace.manifest << {
          name: example.full_description,
          file: example.metadata[:file_path].sub("./", ""),
          line: example.metadata[:line_number],
          status: example.exception ? "failed" : "passed",
          type: example.metadata[:adversarial] ? "adversarial" : "happy",
          trace: filename
        }
      rescue => e
        Rails.logger.warn("[Specbook::Recorders::PlaywrightTrace] stop failed: #{e.message}")
      end
    end

    config.after(:suite) do
      Specbook::Recorders::PlaywrightTrace.write_manifest!
      count = Specbook::Recorders::PlaywrightTrace.manifest.size
      puts "\n🎬 Traces saved to tmp/spec_traces/ (#{count} examples recorded)"
      puts "   View with: npx playwright show-trace tmp/spec_traces/<name>.zip" if count > 0
    end
  end
end
