require "spec_helper"

RSpec.describe "KlyoVaultApp routes" do
  include Rack::Test::Methods

  let(:app) { KlyoVaultApp }
  let(:localhost_env) { { "HTTP_HOST" => "localhost" } }
  let(:drive_client) { instance_double(GoogleDriveFolderClient) }
  let(:photo_metadata_store) { instance_double(PhotoMetadataStore, all: {}, fetch: nil, tagged_count: 0) }
  let(:player_progress_store) do
    instance_double(
      PlayerProgressStore,
      revealed_photo_ids_for_pack: [],
      total_revealed_photo_ids: [],
      reveals_used_today: 0,
      reveal_event_for_photo: nil,
      latest_revealed_photo_id: nil
    )
  end
  let(:user_store) do
    instance_double(
      UserStore,
      count: 0,
      find: nil,
      recent: [],
      find_or_create_from_auth: { "id" => "user-1", "name" => "Player One", "email" => "player@example.com" }
    )
  end

  before do
    allow_any_instance_of(KlyoVaultApp).to receive(:drive_client).and_return(drive_client)
    allow_any_instance_of(KlyoVaultApp).to receive(:openai_tagger).and_return(instance_double(OpenAITagger, configured?: false))

    app.set :user_store, user_store
    app.set :photo_metadata_store, photo_metadata_store
    app.set :player_progress_store, player_progress_store
  end

  it "renders the signed-out landing page" do
    allow(drive_client).to receive(:configured?).and_return(false)

    get "/", {}, localhost_env

    expect(last_response).to be_ok
    expect(last_response.body).to include("Enter the")
    expect(last_response.body).to include("Klyova")
  end

  it "gracefully renders the signed-in lobby when photo loading fails" do
    allow(user_store).to receive(:find).with("user-1").and_return({ "id" => "user-1", "name" => "Player One", "email" => "player@example.com" })
    allow(drive_client).to receive(:configured?).and_return(true)
    allow(drive_client).to receive(:list_photos).and_raise(ArgumentError, "Folder missing")

    get "/", {}, localhost_env.merge("rack.session" => { user_id: "user-1" })

    expect(last_response).to be_ok
    expect(last_response.body).to include("Start from today")
    expect(last_response.body).to include("Photos loaded")
  end

  it "rejects admin access for a non-admin signed-in user" do
    allow(user_store).to receive(:find).with("user-1").and_return({ "id" => "user-1", "name" => "Player One", "email" => "player@example.com" })
    allow(drive_client).to receive(:configured?).and_return(false)
    ENV["ADMIN_EMAILS"] = "owner@example.com"

    get "/admin", {}, localhost_env.merge("rack.session" => { user_id: "user-1" })

    expect(last_response.status).to eq(403)
    expect(last_response.body).to include("Admin access is not enabled for this account.")
  end
end
