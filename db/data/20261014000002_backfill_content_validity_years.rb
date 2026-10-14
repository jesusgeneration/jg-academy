# frozen_string_literal: true

class BackfillContentValidityYears < ActiveRecord::Migration[8.1]
  JSON_PATH = Rails.root.join("db/seeds_data/contents.json")

  def up
    items = JSON.parse(File.read(JSON_PATH))
    items.each do |entry|
      level = Content.find_by(parent: nil, title: entry["title"])
      next if level.nil?

      entry.fetch("sections").each do |section_entry|
        next unless section_entry.key?("validity_years")

        section = Content.find_by(parent: level, title: section_entry["title"])
        section&.update!(validity_years: section_entry["validity_years"])
      end
    end
  end

  def down
    items = JSON.parse(File.read(JSON_PATH))
    titles = items.flat_map do |entry|
      entry.fetch("sections").select { |s| s.key?("validity_years") }.map { |s| s["title"] }
    end
    Content.where(title: titles, content_type: :section).update_all(validity_years: nil)
  end
end
