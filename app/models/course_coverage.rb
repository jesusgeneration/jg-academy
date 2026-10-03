class CourseCoverage < ApplicationRecord
  belongs_to :course
  belongs_to :content

  validates :content_id, uniqueness: { scope: :course_id }
end
