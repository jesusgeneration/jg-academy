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
end
