class KlyoVaultApp < Sinatra::Base
  helpers KlyoVaultHelpers
  register AdminRoutes
  register CoreRoutes
  register GameRoutes

  configure do
    root_path = KlyoVaultBoot.root_path

    set :root, root_path
    set :public_folder, File.join(root_path, "public")
    set :views, File.join(root_path, "views")
    set :session_secret, KlyoVaultBoot.session_secret
    set :user_store, UserStore.new(File.join(root_path, "db", "users.json"))
    set :photo_metadata_store, PhotoMetadataStore.new(File.join(root_path, "db", "photo_metadata.json"))
    set :player_progress_store, PlayerProgressStore.new(File.join(root_path, "db", "player_progress.json"))
  end

  use Rack::Session::Cookie,
    key: "klyovault.session",
    path: "/",
    secret: KlyoVaultBoot.session_secret,
    same_site: :lax

  OmniAuth.config.allowed_request_methods = %i[get post]
  OmniAuth.config.silence_get_warning = true

  use OmniAuth::Builder do
    provider :google_oauth2,
      ENV["GOOGLE_CLIENT_ID"],
      ENV["GOOGLE_CLIENT_SECRET"],
      scope: "openid,email,profile",
      prompt: "select_account"
  end
end
