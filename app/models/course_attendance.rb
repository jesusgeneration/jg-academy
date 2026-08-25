class CourseAttendance < ApplicationRecord
  belongs_to :user
  belongs_to :course

  enum :status, {
    registered: 0,
    attended: 1,
    cancelled: 2,
    no_show: 3
  }

  validates :user_id, uniqueness: { scope: :course_id }
end
