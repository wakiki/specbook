require "rails_helper"

RSpec.describe "Specbook::Viewer", type: :request do
  let(:fixtures_root) { Rails.root.join("..", "fixtures").expand_path }

  before do
    Specbook.instance_variable_set(:@config, Specbook::Configuration.new)
    Specbook.config.screenshot_root = fixtures_root.join("screenshots")
    Specbook.config.feature_root    = fixtures_root.parent.parent
  end

  describe "GET /specs" do
    context "in test env without authorize_with" do
      it "renders the viewer" do
        get "/specs"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Specbook")
      end
    end

    context "with authorize_with returning false" do
      it "redirects to the host root" do
        Specbook.config.authorize_with = ->(_ctrl) { false }
        get "/specs"
        expect(response).to have_http_status(:redirect)
      end
    end

    context "with authorize_with returning true" do
      it "renders the viewer" do
        Specbook.config.authorize_with = ->(_ctrl) { true }
        get "/specs"
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /specs/screenshots/:filename" do
    it "serves a fixture screenshot" do
      get "/specs/screenshots/step_0001_001.png"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("image/png")
    end

    it "rejects path-traversal filenames" do
      get "/specs/screenshots/..%2Fsecret.png"
      expect(response).to have_http_status(:bad_request)
    end

    it "404s for missing files" do
      get "/specs/screenshots/step_9999_999.png"
      expect(response).to have_http_status(:not_found)
    end
  end
end
