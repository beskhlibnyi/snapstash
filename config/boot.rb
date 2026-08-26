require "digest"
require "omniauth"
require "omniauth-google-oauth2"
require "sinatra/base"
require "time"
require_relative "../helpers/klyo_vault_helpers"
require_relative "../routes/admin_routes"
require_relative "../routes/core_routes"
require_relative "../routes/game_routes"
require_relative "../services/env_file"
require_relative "../services/google_drive_folder_client"
require_relative "../services/openai_tagger"
require_relative "../services/photo_grouping_service"
require_relative "../services/photo_metadata_store"
require_relative "../services/player_progress_store"
require_relative "../services/reveal_service"
require_relative "../services/user_store"

module KlyoVaultBoot
  DEFAULT_SESSION_SECRET = "klyovault-dev-session-secret-klyovault-dev-session-secret-2026-safe"

  module_function

  def load_env!
    EnvFile.load(File.expand_path("../.env", __dir__))
  end

  def root_path
    File.expand_path("..", __dir__)
  end

  def env_or_default(key, default)
    value = ENV[key].to_s.strip
    value.empty? ? default : value
  end

  def session_secret
    env_or_default("SESSION_SECRET", DEFAULT_SESSION_SECRET)
  end
end

KlyoVaultBoot.load_env!
