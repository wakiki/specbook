require "rails_helper"

RSpec.describe Specbook::Engine do
  it "is a Rails engine" do
    expect(described_class.ancestors).to include(Rails::Engine)
  end

  it "isolates the Specbook namespace" do
    expect(described_class.isolated?).to be(true)
  end

  it "is mounted at /specs in the dummy app" do
    expect(Rails.application.routes.url_helpers.specbook_path).to eq("/specs")
  end
end
