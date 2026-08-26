require "spec_helper"

RSpec.describe UserStore do
  let(:store_path) { File.join(Dir.mktmpdir, "users.json") }
  let(:store) { described_class.new(store_path) }
  let(:auth_payload) do
    {
      "uid" => "google-123",
      "info" => {
        "email" => "user@example.com",
        "name" => "Example User",
        "image" => "https://example.com/avatar.png"
      }
    }
  end

  it "returns an empty array for malformed json" do
    File.write(store_path, "{broken")

    expect(store.count).to eq(0)
    expect(store.recent).to eq([])
  end

  it "creates and updates a user from auth data" do
    created = store.find_or_create_from_auth(auth_payload)
    updated = store.find_or_create_from_auth(auth_payload.merge("info" => auth_payload["info"].merge("name" => "Updated User")))

    expect(store.count).to eq(1)
    expect(created["id"]).to eq("google-123")
    expect(updated["name"]).to eq("Updated User")
    expect(store.find("google-123")["email"]).to eq("user@example.com")
  end

  it "returns most recent users first" do
    store.find_or_create_from_auth(auth_payload)
    sleep 1
    store.find_or_create_from_auth(auth_payload.merge("uid" => "google-456", "info" => auth_payload["info"].merge("email" => "new@example.com")))

    expect(store.recent(2).map { |user| user["id"] }).to eq(%w[google-456 google-123])
  end
end
