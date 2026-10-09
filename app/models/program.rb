class Program < ApplicationRecord
  belongs_to :organization

  has_many :units, dependent: :restrict_with_error

  has_many :program_attendances, dependent: :destroy
  has_many :users, through: :program_attendances

  enum :kind, {
    schooling: 0,
    freizeit: 1,
    seminar_day: 2,
    youth_weekend: 3,
    staff_preparation: 4
  }

  validates :name, presence: true
  validates :kind, presence: true
end
