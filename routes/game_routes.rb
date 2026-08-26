module GameRoutes
  def self.registered(app)
    app.get "/packs" do
      require_login!
      halt 503, "Google Drive is not configured\n" unless configured?

      @photos = display_photos
      @packs = computed_photo_packs(@photos)
      @grouping_summary = grouping_summary(@photos)
      erb :packs
    rescue StandardError => error
      @load_error = error.message
      @photos = []
      @packs = []
      @grouping_summary = grouping_summary(@photos)
      erb :packs
    end

    app.get "/packs/:id" do
      require_login!
      halt 503, "Google Drive is not configured\n" unless configured?

      @photos = display_photos
      @pack = pack_for_id(params[:id], @photos)
      halt 404, "Pack not found\n" unless @pack

      erb :pack
    rescue StandardError => error
      @load_error = error.message
      halt 500, "#{@load_error}\n"
    end

    app.post "/packs/:id/reveal" do
      require_login!
      halt 503, "Google Drive is not configured\n" unless configured?

      @photos = display_photos
      @pack = pack_for_id(params[:id], @photos)
      halt 404, "Pack not found\n" unless @pack

      result = reveal_service.reveal(user_id: current_user_id, pack: @pack)

      unless result[:ok]
        set_flash(:error, result[:error])
        redirect "/packs/#{@pack['id']}"
      end

      revealed_photo = result[:photo]
      reveal_event = result[:reveal_event]
      set_flash(
        :notice,
        "Reveal complete: #{photo_label(revealed_photo)} unlocked as #{reveal_event['rarity_label']} for #{reveal_event['score']} points."
      )
      redirect "/packs/#{@pack['id']}"
    rescue StandardError => error
      set_flash(:error, "Reveal failed: #{error.message}")
      redirect "/packs/#{params[:id]}"
    end

    app.get "/photos/:id" do
      require_login!
      halt 503, "Google Drive is not configured\n" unless configured?

      @photo = photos.find { |item| item["id"] == params[:id] }
      halt 404, "Photo not found\n" unless @photo

      @winner = winner
      @pack = pack_for_id(params["pack"], photos) if params["pack"]
      if @pack && !photo_revealed_in_pack?(@photo, @pack)
        set_flash(:error, "Reveal this slot from the pack before opening the photo.")
        redirect "/packs/#{@pack['id']}"
      end
      erb :show
    end

    app.get "/drive/files/:id" do
      require_login!
      halt 503, "Google Drive is not configured\n" unless configured?

      file = drive_client.fetch_file(params[:id])
      content_type(file[:content_type] || "application/octet-stream")
      cache_control :public, max_age: 300
      headers["Cache-Control"] = file[:cache_control] if file[:cache_control]
      status file[:status]
      body file[:body]
    rescue StandardError => error
      halt 502, "Could not load file from Google Drive: #{error.message}\n"
    end
  end
end
