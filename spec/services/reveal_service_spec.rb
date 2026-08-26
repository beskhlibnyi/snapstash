require "spec_helper"

RSpec.describe RevealService do
  subject(:service) { described_class.new(player_progress_store: player_progress_store, daily_tries_total: daily_tries_total) }

  let(:player_progress_store) { PlayerProgressStore.new(store_path) }
  let(:store_path) { File.join(Dir.mktmpdir, "player_progress.json") }
  let(:daily_tries_total) { 2 }
  let(:user_id) { "user-1" }
  let(:pack) do
    {
      "id" => "portrait_01",
      "count" => 3,
      "complete" => true,
      "photos" => [
        { "id" => "photo-1", "name" => "One" },
        { "id" => "photo-2", "name" => "Two" },
        { "id" => "photo-3", "name" => "Three" }
      ]
    }
  end

  before do
    allow(service).to receive(:rand).and_return(0)
  end

  it "rejects reveals for incomplete packs" do
    result = service.reveal(user_id: user_id, pack: pack.merge("complete" => false))

    expect(result).to eq(ok: false, error: "This pack needs 3 photos before reveals can start.")
  end

  it "records a reveal event with rarity and score" do
    result = service.reveal(user_id: user_id, pack: pack)

    expect(result[:ok]).to eq(true)
    expect(result[:reveal_event]).to include(
      "pack_id" => "portrait_01",
      "rarity" => "common",
      "rarity_label" => "Common",
      "score" => 10
    )
    expect(result[:reveal_event]["photo_id"]).to eq(result[:photo]["id"])
    expect(player_progress_store.revealed_photo_ids_for_pack(user_id, "portrait_01")).to eq([result[:photo]["id"]])
    expect(player_progress_store.reveal_events(user_id).length).to eq(1)
  end

  it "never reveals the same photo twice within a pack" do
    first = service.reveal(user_id: user_id, pack: pack)
    second = service.reveal(user_id: user_id, pack: pack)

    expect(first[:ok]).to eq(true)
    expect(second[:ok]).to eq(true)
    expect([first[:photo]["id"], second[:photo]["id"]].uniq.length).to eq(2)
  end

  it "enforces the daily reveal limit" do
    2.times { service.reveal(user_id: user_id, pack: pack) }

    result = service.reveal(user_id: user_id, pack: pack)

    expect(result[:ok]).to eq(false)
    expect(result[:error]).to include("You already used all 2 reveals")
  end

  it "returns a failure when a pack is fully revealed" do
    custom_service = described_class.new(player_progress_store: player_progress_store, daily_tries_total: 5)
    3.times { custom_service.reveal(user_id: user_id, pack: pack) }

    result = custom_service.reveal(user_id: user_id, pack: pack)

    expect(result).to eq(ok: false, error: "You already revealed every photo in this pack.")
  end
end
