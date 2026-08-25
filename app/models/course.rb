class Course < ApplicationRecord
  belongs_to :organization

  has_many :course_attendances, dependent: :destroy
  has_many :users, through: :course_attendances

  has_many :course_requirements, dependent: :destroy
  has_many :juleica_requirements, through: :course_requirements

  accepts_nested_attributes_for :course_requirements, allow_destroy: true,
    reject_if: ->(attrs) { attrs["juleica_requirement_id"].blank? || attrs["hours"].blank? }

  validates :name, presence: true
  validates :starts_at, :ends_at, presence: true
  validate :ends_at_after_starts_at

  scope :upcoming, -> { where(ends_at: Time.current..).order(:starts_at) }
  scope :past, -> { where(ends_at: ...Time.current).order(starts_at: :desc) }

  def past?
    ends_at < Time.current
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end
end
