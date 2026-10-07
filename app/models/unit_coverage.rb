class UnitCoverage < ApplicationRecord
  belongs_to :unit
  belongs_to :content

  validates :content_id, uniqueness: { scope: :unit_id }
end
