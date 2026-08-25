class CourseRequirement < ApplicationRecord
  belongs_to :course
  belongs_to :juleica_requirement

  validates :hours, numericality: { greater_than: 0 }
  validates :juleica_requirement_id, uniqueness: { scope: :course_id }
end
