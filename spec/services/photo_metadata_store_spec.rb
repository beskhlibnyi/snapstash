require "spec_helper"

RSpec.describe PhotoMetadataStore do
  let(:store_path) { File.join(Dir.mktmpdir, "photo_metadata.json") }
  let(:store) { described_class.new(store_path) }

  it "returns an empty hash for malformed json" do
    File.write(store_path, "{broken")

    expect(store.all).to eq({})
  end

  it "upserts and merges metadata by photo id" do
    store.upsert("photo-1", "tag_status" => "ai_generated", "ai_tags" => { "short_tags" => ["portrait"] })
    result = store.upsert("photo-1", "approved_tags" => ["portrait"], "tag_status" => "approved")

    expect(result).to include(
      "tag_status" => "approved",
      "approved_tags" => ["portrait"],
      "ai_tags" => { "short_tags" => ["portrait"] }
    )
  end

  it "counts ai generated and approved records as tagged" do
    store.upsert("photo-1", "tag_status" => "ai_generated")
    store.upsert("photo-2", "tag_status" => "approved")
    store.upsert("photo-3", "tag_status" => "pending")

    expect(store.tagged_count).to eq(2)
  end
end
