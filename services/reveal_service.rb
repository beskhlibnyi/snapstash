class RevealService
  DAILY_TRIES_TOTAL = 30000
  RARITY_TABLE = [
    { "key" => "common", "label" => "Common", "weight" => 65, "score" => 10 },
    { "key" => "rare", "label" => "Rare", "weight" => 25, "score" => 30 },
    { "key" => "epic", "label" => "Epic", "weight" => 8, "score" => 80 },
    { "key" => "immortal", "label" => "Immortal", "weight" => 2, "score" => 200 }
  ].freeze

  def initialize(player_progress_store:, daily_tries_total: DAILY_TRIES_TOTAL)
    @player_progress_store = player_progress_store
    @daily_tries_total = daily_tries_total
  end

  attr_reader :daily_tries_total

  def reveal(user_id:, pack:)
    return failure("This pack needs #{pack.fetch('count')} photos before reveals can start.") unless pack["complete"]
    return failure("You already used all #{daily_tries_total} reveals for #{today_label}.") if tries_remaining_for(user_id) <= 0

    revealed_ids = @player_progress_store.revealed_photo_ids_for_pack(user_id, pack["id"])
    unrevealed = Array(pack["photos"]).reject { |photo| revealed_ids.include?(photo["id"]) }
    return failure("You already revealed every photo in this pack.") if unrevealed.empty?

    photo = unrevealed.sample
    rarity = roll_rarity
    reveal_event = {
      "pack_id" => pack["id"],
      "photo_id" => photo["id"],
      "rarity" => rarity["key"],
      "rarity_label" => rarity["label"],
      "score" => rarity["score"],
      "revealed_at" => Time.now.utc.iso8601,
      "day_key" => today_key
    }

    @player_progress_store.record_reveal(user_id: user_id, reveal_event: reveal_event)

    success(photo: photo, reveal_event: reveal_event)
  end

  def tries_used_for(user_id)
    @player_progress_store.reveals_used_today(user_id)
  end

  def tries_remaining_for(user_id)
    [daily_tries_total - tries_used_for(user_id), 0].max
  end

  def rarity_table
    RARITY_TABLE
  end

  private

  def success(photo:, reveal_event:)
    {
      ok: true,
      photo: photo,
      reveal_event: reveal_event
    }
  end

  def failure(message)
    {
      ok: false,
      error: message
    }
  end

  def roll_rarity
    total_weight = RARITY_TABLE.sum { |entry| entry["weight"] }
    roll = rand(total_weight)
    cursor = 0

    RARITY_TABLE.each do |entry|
      cursor += entry["weight"]
      return entry if roll < cursor
    end

    RARITY_TABLE.first
  end

  def today_key
    Time.now.utc.strftime("%F")
  end

  def today_label
    Time.now.strftime("%A, %B %-d, %Y")
  end
end
