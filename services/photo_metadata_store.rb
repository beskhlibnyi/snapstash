require "fileutils"
require "json"

class PhotoMetadataStore
  def initialize(path)
    @path = path
  end

  def all
    load_store
  end

  def fetch(photo_id)
    all[photo_id]
  end

  def upsert(photo_id, attributes)
    store = all
    existing = store[photo_id] || {}
    store[photo_id] = existing.merge(attributes)
    save_store(store)
    store[photo_id]
  end

  def tagged_count
    all.values.count { |entry| entry["tag_status"] == "ai_generated" || entry["tag_status"] == "approved" }
  end

  private

  def load_store
    return {} unless File.exist?(@path)

    data = JSON.parse(File.read(@path))
    data.is_a?(Hash) ? data : {}
  rescue JSON::ParserError
    {}
  end

  def save_store(store)
    FileUtils.mkdir_p(File.dirname(@path))
    File.write(@path, JSON.pretty_generate(store))
  end
end
