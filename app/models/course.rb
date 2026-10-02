class Course < ApplicationRecord
  belongs_to :organization

  has_many :course_attendances, dependent: :destroy
  has_many :users, through: :course_attendances

  has_many :course_coverages, dependent: :destroy
  has_many :covered_contents,
           through: :course_coverages,
           source: :content

  validates :name, presence: true
  validates :starts_at, :ends_at, presence: true
  validate :ends_at_after_starts_at

  scope :upcoming, -> { where(ends_at: Time.current..).order(:starts_at) }
  scope :past, -> { where(ends_at: ...Time.current).order(starts_at: :desc) }

  def past?
    ends_at < Time.current
  end

  def covers?(content)
    return false if content.nil? || id.nil? || content.id.nil?

    ids = [ content.id ]
    return course_coverages.exists?(content_id: ids) if content.level?
    return false unless content.parent_id

    ids << content.parent_id
    return course_coverages.exists?(content_id: ids) if content.section?

    grandparent_id =
      if content.parent&.parent_id
        content.parent.parent_id
      else
        Content.where(id: content.parent_id).pick(:parent_id)
      end
    ids << grandparent_id if grandparent_id

    course_coverages.exists?(content_id: ids.compact)
  end

  private

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end
end
