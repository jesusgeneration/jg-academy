# frozen_string_literal: true

class ImportJuleicaContents < ActiveRecord::Migration[8.1]
  JSON_PATH = Rails.root.join("db/seeds_data/contents.json")

  def up
    items = JSON.parse(File.read(JSON_PATH))
    items.each_with_index do |entry, level_position|
      level = Content.find_or_create_by!(parent: nil, title: entry["title"]) do |content|
        content.content_type = :level
        content.position = level_position
      end
      level.update!(position: level_position) if level.position != level_position

      entry.fetch("sections").each_with_index do |section_entry, section_position|
        section = Content.find_or_create_by!(parent: level, title: section_entry["title"]) do |content|
          content.content_type = :section
          content.position = section_position
        end
        section.update!(position: section_position) if section.position != section_position

        section_entry.fetch("details").each_with_index do |title, detail_position|
          detail = Content.find_or_create_by!(parent: section, title:) do |content|
            content.content_type = :detail
            content.position = detail_position
          end
          detail.update!(position: detail_position) if detail.position != detail_position
        end
      end
    end
  end

  def down
    CourseCoverage.delete_all
    Content.where(content_type: :detail).delete_all
    Content.where(content_type: :section).delete_all
    Content.where(content_type: :level).delete_all
  end
end
