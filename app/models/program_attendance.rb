class ProgramAttendance < ApplicationRecord
  belongs_to :user
  belongs_to :program

  enum :status, {
    registered: 0,
    attended: 1,
    cancelled: 2,
    no_show: 3
  }

  validates :user_id, uniqueness: { scope: :program_id }
end
