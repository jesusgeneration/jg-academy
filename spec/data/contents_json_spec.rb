require "rails_helper"

RSpec.describe "db/seeds_data/contents.json" do
  subject(:items) do
    JSON.parse(File.read(Rails.root.join("db/seeds_data/contents.json")))
  end

  it "contains seven levels" do
    expect(items.size).to eq(7)
  end

  it "has non-blank titles everywhere" do
    titles = items.flat_map do |level|
      [ level["title"], *level.fetch("sections").flat_map { |s| [ s["title"], *s.fetch("details") ] } ]
    end

    expect(titles).to all(be_present.and(be_a(String)))
  end

  it "gives every section at least one detail" do
    items.each do |level|
      level.fetch("sections").each do |section|
        expect(section.fetch("details")).not_to be_empty
      end
    end
  end

  it "holds 27 sections and 72 details" do
    sections = items.sum { |level| level.fetch("sections").size }
    details = items.sum { |level| level.fetch("sections").sum { |s| s.fetch("details").size } }

    aggregate_failures do
      expect(sections).to eq(27)
      expect(details).to eq(72)
    end
  end

  it "nests level 7 details in a section reusing the level title" do
    level7 = items.last

    aggregate_failures do
      expect(level7["sections"].size).to eq(1)
      expect(level7["sections"].sole["title"]).to eq(level7["title"])
      expect(level7["sections"].sole.fetch("details").size).to eq(6)
    end
  end

  it "imports cleanly through the Content validations" do
    items.each_with_index do |entry, level_position|
      level = Content.create!(parent: nil, title: entry["title"], content_type: :level, position: level_position)

      entry.fetch("sections").each_with_index do |section_entry, section_position|
        section = Content.create!(parent: level, title: section_entry["title"], content_type: :section, position: section_position)

        section_entry.fetch("details").each_with_index do |title, detail_position|
          expect(
            Content.new(parent: section, title:, content_type: :detail, position: detail_position)
          ).to be_valid
        end
      end
    end
  end
end
