require "spec_helper"

RSpec.describe PhotoGroupingService do
  subject(:service) { described_class.new(metadata_by_photo_id: metadata_by_photo_id, pack_size: 3) }

  let(:photos) do
    [
      { "id" => "1", "name" => "One" },
      { "id" => "2", "name" => "Two" },
      { "id" => "3", "name" => "Three" },
      { "id" => "4", "name" => "Four" }
    ]
  end

  let(:metadata_by_photo_id) do
    {
      "1" => { "ai_tags" => { "short_tags" => ["Close up portrait", "Window reflection"] } },
      "2" => { "approved_tags" => ["portrait", "indoors"] },
      "3" => { "group_tag" => "Night Out", "ai_tags" => { "short_tags" => ["portrait"] } },
      "4" => { "ai_tags" => { "short_tags" => ["face", "elevator interior"] } }
    }
  end

  describe "#primary_tag_for" do
    it "uses canonical tags from AI metadata" do
      expect(service.primary_tag_for(photos[0])).to eq("portrait")
    end

    it "prefers approved tags over AI tags" do
      expect(service.primary_tag_for(photos[1])).to eq("portrait")
    end

    it "prefers an explicit group tag override" do
      expect(service.primary_tag_for(photos[2])).to eq("night out")
    end

    it "skips ignored generic tags when choosing a primary tag" do
      expect(service.primary_tag_for(photos[3])).to eq("elevator")
    end

    it "falls back to misc when no tags are available" do
      expect(service.primary_tag_for({ "id" => "missing" })).to eq("misc")
    end
  end

  describe "#build_tag_groups" do
    it "groups photos by normalized primary tag and counts remainders" do
      groups = service.build_tag_groups(photos)

      portrait_group = groups.find { |group| group["id"] == "portrait" }
      elevator_group = groups.find { |group| group["id"] == "elevator" }
      night_group = groups.find { |group| group["id"] == "night out" }

      expect(portrait_group).to include(
        "label" => "Portrait",
        "count" => 2,
        "complete_pack_count" => 0,
        "remainder_count" => 2
      )
      expect(elevator_group["photos"].map { |photo| photo["id"] }).to eq(["4"])
      expect(night_group["label"]).to eq("Night Out")
    end
  end

  describe "#build_packs" do
    it "builds deterministic pack ids for complete and incomplete slices" do
      packs = service.build_packs(photos)

      expect(packs.map { |pack| pack["id"] }).to eq(["portrait_01", "elevator_01", "night out_01"])
      expect(packs.find { |pack| pack["id"] == "portrait_01" }).to include("count" => 2, "complete" => false)
    end
  end

  describe "#summary" do
    it "reports group and pack totals" do
      expect(service.summary(photos)).to include(
        "tag_group_count" => 3,
        "pack_count" => 3,
        "complete_pack_count" => 0,
        "incomplete_pack_count" => 3,
        "grouped_photo_count" => 4
      )
    end
  end
end
