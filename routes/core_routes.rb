module CoreRoutes
  def self.registered(app)
    app.get "/" do
      if signed_in? && configured?
        @photos = display_photos
        @winner = winner
      else
        @photos = []
        @winner = nil
      end

      erb :index
    rescue StandardError => error
      @load_error = error.message
      @photos = []
      @winner = nil
      erb :index
    end

    app.get "/auth/failure" do
      @auth_error = params["message"] || "Google sign-in failed."
      @photos = []
      @winner = nil
      erb :index
    end

    app.get "/auth/google_oauth2/callback" do
      auth = request.env["omniauth.auth"]
      halt 401, "Missing Google auth payload\n" unless auth

      user = user_store.find_or_create_from_auth(auth)
      session[:user_id] = user["id"]
      redirect "/"
    end

    app.get "/logout" do
      session.clear
      redirect "/"
    end
  end
end
