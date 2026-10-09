class UnitAttendance < ApplicationRecord
  belongs_to :user
  belongs_to :unit

  enum :status, {
    registered: 0,
    attended: 1,
    cancelled: 2,
    no_show: 3
  }

  validates :user_id, uniqueness: { scope: :unit_id }
  validate :attended_requires_start_time, if: :attended?

  private

  def attended_requires_start_time
    errors.add(:status, :requires_start_time) if unit&.starts_at.blank?
  end
end
