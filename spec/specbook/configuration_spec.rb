require "spec_helper"
require "specbook"

RSpec.describe Specbook::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "has sensible scalar defaults" do
      expect(config.max_runs).to eq(20)
      expect(config.trace_viewer_port).to eq(9322)
      expect(config.actor_colors).to eq({})
      expect(config.ui_domains).to eq([])
      expect(config.back_link).to be_nil
      expect(config.editor_base).to be_nil
      expect(config.authorize_with).to be_nil
    end

    it "ships built-in setup overlay rules" do
      patterns = config.setup_overlay_rules.map { |r| r[:pattern] }
      expect(patterns).to all(be_a(Regexp))
      expect(config.setup_overlay_rules.map { |r| r[:icon] }).to include("🔑", "🔧", "✅")
    end
  end

  describe "path defaults" do
    context "when Rails is defined" do
      it "uses Rails.root for screenshot/trace/feature roots" do
        rails_root = Pathname.new("/tmp/specbook-rails-fake")
        stub_const("Rails", Class.new { define_singleton_method(:root) { rails_root } })

        expect(config.screenshot_root).to eq(rails_root.join("tmp/spec_screenshots"))
        expect(config.trace_root).to eq(rails_root.join("tmp/spec_traces"))
        expect(config.feature_root).to eq(rails_root)
      end
    end

    context "when Rails is not defined" do
      it "falls back to Dir.pwd" do
        hide_const("Rails") if defined?(Rails)
        expect(config.screenshot_root.to_s).to start_with(Dir.pwd)
        expect(config.trace_root.to_s).to start_with(Dir.pwd)
        expect(config.feature_root.to_s).to eq(Dir.pwd)
      end
    end
  end

  describe "writers" do
    it "honours explicit overrides" do
      config.screenshot_root = Pathname.new("/custom/shots")
      config.trace_root      = Pathname.new("/custom/traces")
      config.feature_root    = Pathname.new("/custom/features")

      expect(config.screenshot_root).to eq(Pathname.new("/custom/shots"))
      expect(config.trace_root).to eq(Pathname.new("/custom/traces"))
      expect(config.feature_root).to eq(Pathname.new("/custom/features"))
    end
  end
end
