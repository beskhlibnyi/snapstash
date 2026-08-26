class PhotoGroupingService
  DEFAULT_PACK_SIZE = 3
  IGNORED_PRIMARY_TAGS = [
    "vertical photo",
    "vertical composition",
    "vertical framing",
    "indoor scene",
    "indoors",
    "person",
    "face"
  ].freeze

  CANONICAL_TAG_MAP = {
    "close up portrait" => "portrait",
    "close-up portrait" => "portrait",
    "candid portrait" => "portrait",
    "portrait" => "portrait",
    "close up selfie" => "selfie",
    "close-up selfie" => "selfie",
    "selfie style" => "selfie",
    "selfie" => "selfie",
    "window reflection" => "window",
    "plain indoor background" => "indoor",
    "interior corner" => "indoor",
    "home interior" => "indoor",
    "closet interior" => "closet",
    "elevator interior" => "elevator"
  }.freeze

  def initialize(metadata_by_photo_id:, pack_size: DEFAULT_PACK_SIZE)
    @metadata_by_photo_id = metadata_by_photo_id || {}
    @pack_size = pack_size
  end

  attr_reader :pack_size

  def build_tag_groups(photos)
    grouped = photos.each_with_object({}) do |photo, memo|
      tag = primary_tag_for(photo)
      memo[tag] ||= {
        "id" => tag,
        "label" => display_label_for(tag),
        "primary_tag" => tag,
        "photos" => []
      }
      memo[tag]["photos"] << photo
    end

    grouped.values
      .sort_by { |group| [-group["photos"].length, group["label"]] }
      .map do |group|
        group.merge(
          "count" => group["photos"].length,
          "complete_pack_count" => group["photos"].length / pack_size,
          "remainder_count" => group["photos"].length % pack_size
        )
      end
  end

  def build_packs(photos)
    build_tag_groups(photos).flat_map do |group|
      group["photos"].each_slice(pack_size).with_index(1).map do |slice, index|
        {
          "id" => "#{group['id']}_#{index.to_s.rjust(2, '0')}",
          "label" => pack_label_for(group, index),
          "primary_tag" => group["primary_tag"],
          "photos" => slice,
          "count" => slice.length,
          "complete" => slice.length == pack_size
        }
      end
    end
  end

  def summary(photos)
    groups = build_tag_groups(photos)
    packs = build_packs(photos)

    {
      "tag_group_count" => groups.length,
      "pack_count" => packs.length,
      "complete_pack_count" => packs.count { |pack| pack["complete"] },
      "incomplete_pack_count" => packs.count { |pack| !pack["complete"] },
      "grouped_photo_count" => photos.length
    }
  end

  def primary_tag_for(photo)
    metadata = @metadata_by_photo_id.fetch(photo["id"], {})
    explicit_tag = normalize_tag(metadata["group_tag"])
    return explicit_tag unless explicit_tag.empty?

    tags = preferred_tags(metadata)
    selected = tags.find { |tag| !ignored_primary_tag?(tag) } || tags.first
    selected.to_s.empty? ? "misc" : selected
  end

  private

  def preferred_tags(metadata)
    approved_tags = Array(metadata["approved_tags"]).map { |tag| normalize_tag(tag) }.reject(&:empty?)
    return approved_tags unless approved_tags.empty?

    short_tags = Array(metadata.dig("ai_tags", "short_tags")).map { |tag| normalize_tag(tag) }.reject(&:empty?)
    return short_tags unless short_tags.empty?

    []
  end

  def normalize_tag(tag)
    normalized = tag.to_s
      .downcase
      .gsub(/[^a-z0-9]+/, " ")
      .strip
      .gsub(/\s+/, " ")

    CANONICAL_TAG_MAP.fetch(normalized, normalized)
  end

  def ignored_primary_tag?(tag)
    IGNORED_PRIMARY_TAGS.include?(tag)
  end

  def display_label_for(tag)
    return "Misc" if tag == "misc"

    tag.split.map(&:capitalize).join(" ")
  end

  def pack_label_for(group, index)
    return group["label"] if group["count"] <= pack_size

    "#{group['label']} #{index.to_s.rjust(2, '0')}"
  end
end
