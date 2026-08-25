class JuleicaRequirement < ApplicationRecord
  has_many :course_requirements, dependent: :restrict_with_error
  has_many :courses, through: :course_requirements

  validates :name, presence: true
  validates :required_hours, numericality: { greater_than: 0 }
end
