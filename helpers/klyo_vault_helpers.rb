require "digest"
require "time"

module KlyoVaultHelpers
  def user_store
    settings.user_store
  end

  def photo_metadata_store
    settings.photo_metadata_store
  end

  def player_progress_store
    settings.player_progress_store
  end

  def drive_client
    @drive_client ||= GoogleDriveFolderClient.new(
      api_key: ENV["GOOGLE_DRIVE_API_KEY"],
      folder_id: ENV["GOOGLE_DRIVE_FOLDER_ID"]
    )
  end

  def openai_tagger
    @openai_tagger ||= OpenAITagger.new(
      api_key: ENV["OPENAI_API_KEY"],
      model: ENV.fetch("TAGGING_MODEL", OpenAITagger::DEFAULT_MODEL)
    )
  end

  def photo_grouping_service
    @photo_grouping_service ||= PhotoGroupingService.new(
      metadata_by_photo_id: photo_metadata_store.all
    )
  end

  def reveal_service
    @reveal_service ||= RevealService.new(player_progress_store: player_progress_store)
  end

  def grouping_pack_size
    photo_grouping_service.pack_size
  end

  def google_login_configured?
    ENV["GOOGLE_CLIENT_ID"].to_s.strip != "" && ENV["GOOGLE_CLIENT_SECRET"].to_s.strip != ""
  end

  def configured?
    drive_client.configured?
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = user_store.find(session[:user_id]) if session[:user_id]
  end

  def signed_in?
    !current_user.nil?
  end

  def vault_member_count
    user_store.count
  end

  def current_user_name
    return "Vault member" unless signed_in?

    current_user["name"].to_s.strip.empty? ? "Vault member" : current_user["name"]
  end

  def current_user_first_name
    current_user_name.split(/\s+/).first
  end

  def current_user_id
    signed_in? ? current_user["id"] : nil
  end

  def admin_emails
    ENV.fetch("ADMIN_EMAILS", "")
      .split(",")
      .map { |email| email.strip.downcase }
      .reject(&:empty?)
  end

  def admin_bootstrap_mode?
    admin_emails.empty? && vault_member_count <= 1
  end

  def admin?
    return false unless signed_in?

    if admin_emails.empty?
      admin_bootstrap_mode?
    else
      admin_emails.include?(current_user["email"].to_s.downcase)
    end
  end

  def admin_console_visible?
    signed_in? && admin?
  end

  def admin_access_label
    admin_bootstrap_mode? ? "Bootstrap mode" : "Allowlist mode"
  end

  def admin_access_copy
    if admin_bootstrap_mode?
      "Only one vault member exists right now, so that account can access admin until ADMIN_EMAILS is set."
    else
      "Admin access is locked to the Google emails listed in ADMIN_EMAILS."
    end
  end

  def recent_vault_members(limit = 5)
    user_store.recent(limit)
  end

  def tagging_configured?
    openai_tagger.configured?
  end

  def photo_metadata(photo)
    photo_metadata_store.fetch(photo["id"]) || {}
  end

  def photo_tag_status(photo)
    photo_metadata(photo)["tag_status"].to_s
  end

  def photo_short_tags(photo)
    Array(photo_metadata(photo).dig("ai_tags", "short_tags"))
  end

  def tagged_photo_count
    photo_metadata_store.tagged_count
  end

  def grouping_summary(source_photos = @photos || photos)
    photo_grouping_service.summary(source_photos)
  end

  def computed_tag_groups(source_photos = @photos || photos)
    photo_grouping_service.build_tag_groups(source_photos)
  end

  def computed_photo_packs(source_photos = @photos || photos)
    photo_grouping_service.build_packs(source_photos)
  end

  def pack_for_id(pack_id, source_photos = @photos || photos)
    computed_photo_packs(source_photos).find { |pack| pack["id"] == pack_id }
  end

  def pack_cover_photo(pack)
    Array(pack["photos"]).first
  end

  def primary_group_tag(photo)
    photo_grouping_service.primary_tag_for(photo)
  end

  def pack_revealed_photo_ids(pack)
    return [] unless signed_in?

    player_progress_store.revealed_photo_ids_for_pack(current_user_id, pack["id"])
  end

  def pack_revealed_count(pack)
    pack_revealed_photo_ids(pack).length
  end

  def pack_complete_for_user?(pack)
    pack_revealed_count(pack) >= pack["count"]
  end

  def pack_ready_to_play?(pack)
    pack["complete"]
  end

  def photo_revealed_in_pack?(photo, pack)
    pack_revealed_photo_ids(pack).include?(photo["id"])
  end

  def photo_reveal_event(photo)
    return nil unless signed_in?

    player_progress_store.reveal_event_for_photo(current_user_id, photo["id"])
  end

  def photo_rarity_key(photo)
    event = photo_reveal_event(photo)
    event && event["rarity"]
  end

  def photo_rarity_label(photo)
    event = photo_reveal_event(photo)
    event && event["rarity_label"]
  end

  def photo_reveal_score(photo)
    event = photo_reveal_event(photo)
    event && event["score"]
  end

  def untagged_photos(source_photos)
    source_photos.reject { |photo| photo_tag_status(photo) == "ai_generated" || photo_tag_status(photo) == "approved" }
  end

  def daily_tries_total
    reveal_service.daily_tries_total
  end

  def daily_tries_used
    return 0 unless signed_in?

    reveal_service.tries_used_for(current_user_id)
  end

  def daily_tries_remaining
    [daily_tries_total - daily_tries_used, 0].max
  end

  def collection_unlocked_count
    return 0 unless signed_in?

    player_progress_store.total_revealed_photo_ids(current_user_id).length
  end

  def collection_completion_percent
    return 0 if photos.empty?

    ((collection_unlocked_count.to_f / photos.length) * 100).round
  end

  def best_find_label
    return "No reveal yet" unless signed_in? && configured?

    photo_id = player_progress_store.latest_revealed_photo_id(current_user_id)
    return "No reveal yet" if photo_id.to_s.empty?

    revealed_photo = photos.find { |photo| photo["id"] == photo_id }
    return "No reveal yet" unless revealed_photo

    rarity = photo_rarity_label(revealed_photo)
    rarity ? "#{rarity} #{photo_label(revealed_photo)}" : photo_label(revealed_photo)
  end

  def streak_label
    "Starts today"
  end

  def require_login!
    return if signed_in?

    redirect "/"
  end

  def require_admin!
    require_login!
    halt 403, "Admin access is not enabled for this account.\n" unless admin?
  end

  def set_flash(type, message)
    session[:flash] ||= {}
    session[:flash][type.to_s] = message
  end

  def flash_messages
    session.delete(:flash) || {}
  end

  def photos
    @photos ||= drive_client.list_photos
  end

  def display_photos
    @display_photos ||= stable_shuffle(photos, "display-order")
  end

  def winner
    return nil if photos.empty?

    winner_id = seeded_id(photos.map { |photo| photo["id"] }, "winner")
    photos.find { |photo| photo["id"] == winner_id }
  end

  def winning_photo?(photo)
    winner && winner["id"] == photo["id"]
  end

  def seeded_id(ids, namespace)
    ordered_ids = ids.compact.sort
    return nil if ordered_ids.empty?

    digest = Digest::SHA256.hexdigest("#{winning_seed}:#{namespace}:#{ordered_ids.join(':')}")
    ordered_ids[digest.to_i(16) % ordered_ids.length]
  end

  def stable_shuffle(items, namespace)
    items.sort_by do |item|
      Digest::SHA256.hexdigest("#{winning_seed}:#{namespace}:#{item['id']}")
    end
  end

  def winning_seed
    ENV.fetch("WINNING_PHOTO_SEED", "klyovault-prototype")
  end

  def photo_url(photo)
    remote_photo_url(photo) || "/drive/files/#{photo['id']}"
  end

  def photo_thumbnail_url(photo)
    photo["thumbnail_link"].to_s.strip.empty? ? photo_url(photo) : photo["thumbnail_link"]
  end

  def remote_photo_url(photo)
    link = photo["web_content_link"].to_s.strip
    return nil if link.empty?

    link
  end

  def photo_view_url(photo)
    link = photo["web_view_link"].to_s.strip
    return photo_url(photo) if link.empty?

    link
  end

  def photo_label(photo)
    return photo["name"] unless photo["name"].to_s.empty?

    "Untitled photo"
  end

  def formatted_timestamp(value)
    return nil if value.to_s.empty?

    Time.parse(value).strftime("%b %-d, %Y")
  rescue ArgumentError
    value
  end
end
