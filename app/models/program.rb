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

  # Date-based tabs mirroring the unit filters. A program counts as
  # upcoming with at least one upcoming unit, as past with past but no
  # upcoming units, and as planned when none of its units is scheduled
  # (including programs without any units).
  scope :upcoming, -> { where(id: Unit.upcoming.select(:program_id)) }
  scope :past, -> {
    where(id: Unit.past.select(:program_id))
      .where.not(id: Unit.upcoming.select(:program_id))
  }
  scope :planned, -> { where.not(id: Unit.where.not(starts_at: nil).select(:program_id)) }
end
