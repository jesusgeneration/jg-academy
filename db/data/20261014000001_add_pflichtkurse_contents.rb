# frozen_string_literal: true

class AddPflichtkurseContents < ActiveRecord::Migration[8.1]
  LEVEL_TITLE = "Pflichtkurse"
  SECTION_TITLES = [
    "Prävention sexualisierter Gewalt",
    "Erste Hilfe"
  ].freeze

  def up
    level = Content.find_or_create_by!(parent: nil, title: LEVEL_TITLE) do |content|
      content.content_type = :level
      content.position = next_level_position
    end

    SECTION_TITLES.each_with_index do |title, section_position|
      section = Content.find_or_create_by!(parent: level, title:) do |content|
        content.content_type = :section
        content.position = section_position
      end
      section.update!(position: section_position) if section.position != section_position
    end
  end

  def down
    level = Content.find_by(parent: nil, title: LEVEL_TITLE)
    return if level.nil?

    section_ids = Content.where(parent: level).pluck(:id)
    detail_ids = Content.where(parent_id: section_ids).pluck(:id)
    UnitCoverage.where(content_id: [ level.id ] + section_ids + detail_ids).delete_all
    Content.where(id: detail_ids).delete_all
    Content.where(id: section_ids).delete_all
    level.destroy!
  end

  private

  def next_level_position
    Content.where(parent_id: nil).maximum(:position).to_i + 1
  end
end
