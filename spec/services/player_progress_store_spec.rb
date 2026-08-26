require "spec_helper"

RSpec.describe PlayerProgressStore do
  let(:store_path) { File.join(Dir.mktmpdir, "player_progress.json") }
  let(:store) { described_class.new(store_path) }
  let(:event) do
    {
      "pack_id" => "portrait_01",
      "photo_id" => "photo-1",
      "rarity" => "rare",
      "rarity_label" => "Rare",
      "score" => 30,
      "day_key" => Time.now.utc.strftime("%F"),
      "revealed_at" => Time.now.utc.iso8601
    }
  end

  it "returns default empty state for a new user" do
    expect(store.revealed_photo_ids_for_pack("user-1", "portrait_01")).to eq([])
    expect(store.total_revealed_photo_ids("user-1")).to eq([])
    expect(store.reveal_events("user-1")).to eq([])
  end

  it "returns an empty state for malformed json" do
    File.write(store_path, "{broken")

    expect(store.reveal_events("user-1")).to eq([])
  end

  it "records reveal state and keeps user data isolated" do
    store.record_reveal(user_id: "user-1", reveal_event: event)
    store.record_reveal(user_id: "user-2", reveal_event: event.merge("photo_id" => "photo-2"))

    expect(store.revealed_photo_ids_for_pack("user-1", "portrait_01")).to eq(["photo-1"])
    expect(store.total_revealed_photo_ids("user-2")).to eq(["photo-2"])
    expect(store.latest_revealed_photo_id("user-1")).to eq("photo-1")
  end

  it "deduplicates revealed photo ids while preserving reveal events" do
    2.times { store.record_reveal(user_id: "user-1", reveal_event: event) }

    expect(store.total_revealed_photo_ids("user-1")).to eq(["photo-1"])
    expect(store.reveal_events("user-1").length).to eq(2)
    expect(store.reveals_used_today("user-1")).to eq(2)
  end
end
