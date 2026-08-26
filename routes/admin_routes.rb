require "time"

module AdminRoutes
  def self.registered(app)
    app.get "/admin" do
      require_admin!

      @photos = configured? ? display_photos : []
      @recent_photos = @photos.first(12)
      @recent_members = recent_vault_members(6)
      @grouping_summary = grouping_summary(@photos)
      @computed_tag_groups = computed_tag_groups(@photos)
      @computed_photo_packs = computed_photo_packs(@photos)
      erb :admin
    rescue StandardError => error
      @admin_error = error.message
      @photos = []
      @recent_photos = []
      @recent_members = recent_vault_members(6)
      @grouping_summary = grouping_summary(@photos)
      @computed_tag_groups = []
      @computed_photo_packs = []
      erb :admin
    end

    app.post "/admin/tagging/run" do
      require_admin!
      halt 503, "Google Drive is not configured\n" unless configured?
      halt 503, "OpenAI tagging is not configured\n" unless tagging_configured?

      @photos = display_photos
      pending_photos = untagged_photos(@photos)
      limit = [[params.fetch("limit", "5").to_i, 1].max, 20].min
      selected_photos = pending_photos.first(limit)

      tagged = selected_photos.map do |photo|
        tags = openai_tagger.tag_photo(photo)
        saved = photo_metadata_store.upsert(
          photo["id"],
          {
            "drive_file_id" => photo["id"],
            "filename" => photo["name"],
            "thumbnail_url" => photo["thumbnail_link"],
            "ai_tags" => tags,
            "approved_tags" => nil,
            "tag_status" => "ai_generated",
            "tagged_at" => Time.now.utc.iso8601
          }
        )

        { photo: photo, tags: saved["ai_tags"] }
      end

      @tag_run = {
        requested_limit: limit,
        tagged_count: tagged.length,
        skipped_count: pending_photos.length - tagged.length,
        tagged: tagged
      }
      @recent_photos = @photos.first(12)
      @recent_members = recent_vault_members(6)
      @grouping_summary = grouping_summary(@photos)
      @computed_tag_groups = computed_tag_groups(@photos)
      @computed_photo_packs = computed_photo_packs(@photos)
      erb :admin
    rescue StandardError => error
      @admin_error = error.message
      @photos = configured? ? display_photos : []
      @recent_photos = @photos.first(12)
      @recent_members = recent_vault_members(6)
      @grouping_summary = grouping_summary(@photos)
      @computed_tag_groups = computed_tag_groups(@photos)
      @computed_photo_packs = computed_photo_packs(@photos)
      erb :admin
    end
  end
end
