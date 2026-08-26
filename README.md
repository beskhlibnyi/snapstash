# KlyoVault

KlyoVault is a Sinatra/Ruby 4 prototype for a private photo collection game backed by
one Google Drive folder.

Current player flow:

- users sign in with Google
- the app loads photos from a configured Google Drive folder
- photos are grouped into tag-based packs of 3
- signed-in users spend daily reveals to unlock one random unrevealed photo from a pack
- each reveal gets a rarity and score and is saved per user
- unlocked photo pages still show whether that photo matches the current deterministic
  global winner

Current admin flow:

- admin accounts can open `/admin`
- admins can review collection/member stats
- admins can run OpenAI-powered tagging for untagged photos
- generated tags are stored locally and reused for grouping

## What the app includes

- Google OAuth sign-in with cookie sessions
- Google Drive photo listing and image proxying
- local JSON persistence for users, photo metadata, and player progress under `db/`
- tag normalization and grouping through `PhotoGroupingService`
- pack generation with 3-photo packs
- per-user reveals, rarity rolls, score tracking, and collection progress
- an admin console with bootstrap access mode and optional email allowlist

## Current auth/data model

This prototype currently uses:

- one Google OAuth web client for sign-in
- one `GOOGLE_DRIVE_FOLDER_ID`
- one `GOOGLE_DRIVE_API_KEY`
- one shared Drive folder that is readable through the current API key setup

This is still prototype infrastructure. If the final product needs truly private per-user
storage, the Drive access model should move away from the current API-key-based folder read.

## Environment setup

Create a local `.env` file from the example:

```bash
cp .env.example .env
```

Then fill in the values you need:

```dotenv
GOOGLE_CLIENT_ID=your_google_oauth_client_id_here
GOOGLE_CLIENT_SECRET=your_google_oauth_client_secret_here
GOOGLE_DRIVE_API_KEY=your_google_api_key_here
GOOGLE_DRIVE_FOLDER_ID=your_drive_folder_id_here
SESSION_SECRET=change_this_to_a_long_random_string
ADMIN_EMAILS=you@example.com
OPENAI_API_KEY=your_openai_api_key_here
TAGGING_MODEL=gpt-5.6-luna
WINNING_PHOTO_SEED=klyovault-prototype
```

Environment variables used by the app:

- `GOOGLE_CLIENT_ID`: required for Google sign-in
- `GOOGLE_CLIENT_SECRET`: required for Google sign-in
- `GOOGLE_DRIVE_API_KEY`: required to list/proxy photos from Drive
- `GOOGLE_DRIVE_FOLDER_ID`: required Drive folder source
- `SESSION_SECRET`: recommended; if omitted, the app falls back to a built-in development
  secret
- `ADMIN_EMAILS`: optional comma-separated allowlist for admin access
- `OPENAI_API_KEY`: optional; required only for `/admin` tagging runs
- `TAGGING_MODEL`: optional; defaults to `gpt-5.6-luna`
- `WINNING_PHOTO_SEED`: optional seed for the deterministic winner photo

Admin access behavior:

- if `ADMIN_EMAILS` is set, only those Google emails can use `/admin`
- if `ADMIN_EMAILS` is blank and the vault has 0 or 1 saved member, the app enables a
  one-user bootstrap admin mode

## Google OAuth setup

In Google Cloud Console:

1. Go to `APIs & Services` -> `Credentials`
2. Create an `OAuth client ID`
3. Choose `Web application`
4. Add this Authorized redirect URI:

```text
http://127.0.0.1:9292/auth/google_oauth2/callback
```

If you use `localhost`, also add:

```text
http://localhost:9292/auth/google_oauth2/callback
```

Copy the generated client ID and client secret into `.env`.

## Google Drive folder setup

If your folder URL looks like:

```text
https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOpQrStUvWxYz
```

then the folder ID is:

```text
1AbCdEfGhIjKlMnOpQrStUvWxYz
```

This version expects a Drive folder that the current API key setup can read.

## Setup

```bash
rbenv install 4.0.0
rbenv local 4.0.0
gem install bundler
bundle install
```

## Run

```bash
bundle exec rackup
```

Then open [http://127.0.0.1:9292](http://127.0.0.1:9292).

## Main routes

- `/`: signed-out entry or signed-in player lobby
- `/packs`: grouped pack collection
- `/packs/:id`: single pack reveal screen
- `/packs/:id/reveal`: reveal action for the current user
- `/photos/:id`: unlocked photo detail page
- `/admin`: admin dashboard

## Notes and current prototype edges

- pack grouping depends on local metadata and tag generation
- packs are currently built in slices of 3 photos
- the current daily reveal limit is a development value from `RevealService` and is not
  yet configurable
- the app stores state in local JSON files and is not hardened for concurrent writes
- the deterministic winner mechanic still exists alongside the pack/reveal system
- this is a prototype, not a production-ready backend
