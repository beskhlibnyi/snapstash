class PlayerProgressStore
  def initialize(path)
    @path = path
  end

  def revealed_photo_ids_for_pack(user_id, pack_id)
    state_for(user_id).dig("revealed_photo_ids_by_pack", pack_id) || []
  end

  def total_revealed_photo_ids(user_id)
    state_for(user_id)["revealed_photo_ids"] || []
  end

  def reveal_events(user_id)
    Array(state_for(user_id)["reveal_events"])
  end

  def reveal_event_for_photo(user_id, photo_id)
    reveal_events(user_id).reverse.find { |event| event["photo_id"] == photo_id }
  end

  def latest_revealed_photo_id(user_id)
    event = reveal_events(user_id).last
    event && event["photo_id"]
  end

  def reveals_used_today(user_id)
    reveal_events_for_date(user_id, today_key).length
  end

  def record_reveal(user_id:, reveal_event:)
    state = state_for(user_id)
    state["revealed_photo_ids_by_pack"] ||= {}
    state["revealed_photo_ids_by_pack"][reveal_event["pack_id"]] ||= []
    state["revealed_photo_ids_by_pack"][reveal_event["pack_id"]] << reveal_event["photo_id"]
    state["revealed_photo_ids_by_pack"][reveal_event["pack_id"]].uniq!

    state["revealed_photo_ids"] ||= []
    state["revealed_photo_ids"] << reveal_event["photo_id"]
    state["revealed_photo_ids"].uniq!

    state["reveal_events"] ||= []
    state["reveal_events"] << reveal_event

    save_state(user_id, state)
    reveal_event
  end

  private

  def today_key
    Time.now.utc.strftime("%F")
  end

  def reveal_events_for_date(user_id, day_key)
    Array(state_for(user_id)["reveal_events"]).select { |event| event["day_key"] == day_key }
  end

  def state_for(user_id)
    store = load_store
    store[user_id.to_s] ||= {
      "revealed_photo_ids" => [],
      "revealed_photo_ids_by_pack" => {},
      "reveal_events" => []
    }
    store[user_id.to_s]
  end

  def save_state(user_id, state)
    store = load_store
    store[user_id.to_s] = state
    FileUtils.mkdir_p(File.dirname(@path))
    File.write(@path, JSON.pretty_generate(store))
  end

  def load_store
    return {} unless File.exist?(@path)

    data = JSON.parse(File.read(@path))
    data.is_a?(Hash) ? data : {}
  rescue JSON::ParserError
    {}
  end
end
