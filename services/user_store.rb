require "fileutils"
require "json"
require "time"

class UserStore
  def initialize(path)
    @path = path
  end

  def recent(limit = 5)
    all
      .sort_by { |user| user["last_login_at"].to_s }
      .reverse
      .first(limit)
  end

  def count
    all.length
  end

  def find(user_id)
    all.find { |user| user["id"] == user_id }
  end

  def find_or_create_from_auth(auth)
    users = all
    uid = auth.fetch("uid")
    info = auth.fetch("info", {})

    user = users.find { |entry| entry["id"] == uid } || { "id" => uid, "created_at" => Time.now.utc.iso8601 }
    user["email"] = info["email"]
    user["name"] = info["name"] || info["email"] || "Google user"
    user["image"] = info["image"]
    user["updated_at"] = Time.now.utc.iso8601
    user["last_login_at"] = Time.now.utc.iso8601

    existing_index = users.index { |entry| entry["id"] == uid }
    if existing_index
      users[existing_index] = user
    else
      users << user
    end

    save(users)
    user
  end

  private

  def all
    return [] unless File.exist?(@path)

    JSON.parse(File.read(@path))
  rescue JSON::ParserError
    []
  end

  def save(users)
    FileUtils.mkdir_p(File.dirname(@path))
    File.write(@path, JSON.pretty_generate(users.sort_by { |user| user["created_at"].to_s }))
  end
end
