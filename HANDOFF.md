# KlyoVault Session Handoff

Last updated: 2026-08-26

## Ready-to-paste prompt

Continue work on KlyoVault in `/Users/yaroslavbeskhlibnyi/projectsv2/snapstash`.
Read `HANDOFF.md` and `README.md`, then inspect the current code before editing. Start
with Phase 1 below: bring the documentation in sync with the implemented app and add
focused automated tests for grouping, reveals, and JSON persistence. Preserve the
existing visual design and local data. Do not expose or replace `.env` secrets. Run
the test suite and Ruby syntax checks before handing back the result.

## Current state

KlyoVault is a Sinatra/Ruby 4 prototype backed by a configured Google Drive folder.
The dependency bundle is currently healthy, and all Ruby files pass syntax checks.
There is no test suite yet. This directory is not currently recognized as a Git
repository, so do not assume commit history is available.

Implemented behavior:

- Google OAuth sign-in and cookie sessions.
- Google Drive photo listing and image proxying.
- Local JSON user, photo metadata, and player progress stores under `db/`.
- Admin access through `ADMIN_EMAILS`, with a one-user bootstrap mode.
- OpenAI image tagging through the Responses API.
- Tag normalization, grouping, and three-photo pack generation.
- Per-user random reveals, rarity rolls, scores, daily usage tracking, and collection
  progress.
- Player pages for the lobby, pack collection, individual pack reveals, and unlocked
  photo details.
- A developed responsive visual layer in `views/` and `public/styles.css`.

The README describes an earlier version and does not yet document tagging, grouping,
packs, reveals, the admin console, or all environment variables.

## Suggested plan

### Phase 1: Stabilize and document

1. Update `README.md` to match actual behavior and document `ADMIN_EMAILS`,
   `OPENAI_API_KEY`, and `TAGGING_MODEL` without including real values.
2. Add a lightweight test stack suitable for Sinatra/Ruby 4 (for example Minitest and
   Rack::Test).
3. Add unit tests for `PhotoGroupingService`, including canonical tags, ignored tags,
   incomplete packs, and deterministic pack IDs.
4. Add unit tests for `RevealService`, including complete/incomplete packs, exhausted
   daily tries, no duplicate reveal within a pack, rarity event shape, and score
   persistence.
5. Add store tests using temporary directories for malformed JSON, upserts, and
   per-user isolation. Never mutate the real files under `db/` in tests.
6. Add basic route smoke tests with Drive/OpenAI clients stubbed so tests do not make
   network requests.

Acceptance criteria: `bundle exec ruby -Itest` (or the chosen test command) passes,
all Ruby files pass `ruby -c`, and README setup/run instructions match the app.

### Phase 2: Remove prototype inconsistencies

1. Make the daily reveal limit configurable; `RevealService::DAILY_TRIES_TOTAL` is
   currently `30000`, which appears to be a development value.
2. Replace stale UI copy claiming that grouping, rarity, or scoring are still future
   work; those features already exist.
3. Decide the relationship between the deterministic global "winner" and per-user
   rarity/score reveals. The winner is currently shown immediately after an unlocked
   photo is opened.
4. Implement the displayed login streak or remove the placeholder `"Starts today"`.
5. Review pack identity stability: pack IDs derive from the selected primary tag and
   slice order, so retagging or Drive ordering changes can orphan saved progress.

Acceptance criteria: player-facing copy describes current behavior, limits come from
configuration, and saved progress has an explicit strategy when packs change.

### Phase 3: Admin curation and durability

1. Add admin controls to approve/edit AI tags and set an explicit `group_tag`; the
   data model supports these fields, but the current UI only generates tags.
2. Add CSRF protection to state-changing forms and tighten production cookie/session
   settings.
3. Replace or harden direct JSON writes before multi-process or hosted deployment.
   Current read-modify-write operations have no locking and can lose concurrent
   updates.
4. Add graceful timeouts/retries for Google Drive and OpenAI requests and avoid
   exposing raw upstream response bodies to users.

## Important files

- `app.rb`, `config/boot.rb`, `config/klyo_vault_app.rb`: application boot and setup.
- `helpers/klyo_vault_helpers.rb`: shared auth, grouping, progress, and photo helpers.
- `routes/`: core auth, admin tagging, and game routes.
- `services/photo_grouping_service.rb`: tag selection and pack construction.
- `services/reveal_service.rb`: reveal limits, rarity, and scoring.
- `services/*_store.rb`: local JSON persistence.
- `views/` and `public/styles.css`: established UI; preserve its design language.
- `.env.example`: safe configuration key inventory.

## Relay setup context

`codex-relay` requires Node `>=22.14.0`; Node `v22.21.1` is installed through nvm.
The earlier Node 16 error from `@hono/node-server` was resolved by switching Node.
Pair approval previously failed with `ECONNREFUSED 127.0.0.1:8787` because the relay
server was not running. The intended flow is to keep `npx codex-relay@latest` running
(or start it with `--bg`) before running the `approve` command. Pairing was reported
as likely complete, but a future session can verify with:

```bash
lsof -nP -iTCP:8787 -sTCP:LISTEN
```

Do not reuse the old pairing code from chat; generate a fresh QR/code if pairing must
be repeated.

## Verification performed

On 2026-08-26:

- `ruby -v` returned Ruby 4.0.0.
- `bundle check` reported that dependencies are satisfied.
- `bundle exec ruby -c app.rb` passed.
- Syntax checks passed for all Ruby files in `config/`, `routes/`, `services/`, and
  `helpers/`.
