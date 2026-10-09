class Unit < ApplicationRecord
  belongs_to :program

  has_many :unit_attendances, dependent: :destroy
  has_many :users, through: :unit_attendances

  has_many :unit_coverages, dependent: :destroy
  has_many :covered_contents,
           through: :unit_coverages,
           source: :content

  delegate :organization, to: :program

  # Status mapping when copying the program roster onto a unit:
  # a program-level "attended" becomes "registered" on the unit.
  def self.inherited_status(status)
    status.to_s == "attended" ? "registered" : status.to_s
  end

  # Splits the program roster into unit additions, conflicts needing a
  # decision, and entries already matching. Existing unit entries are never
  # removed by inheritance.
  def attendance_inheritance_preview
    existing = unit_attendances.index_by(&:user_id)
    add = []
    conflicts = []
    unchanged = 0
    program.program_attendances.includes(:user).order("users.email").each do |program_attendance|
      mapped = self.class.inherited_status(program_attendance.status)
      unit_attendance = existing[program_attendance.user_id]
      if unit_attendance.nil?
        add << program_attendance
      elsif unit_attendance.status == mapped
        unchanged += 1
      else
        conflicts << {
          user: program_attendance.user,
          program_attendance: program_attendance,
          unit_attendance: unit_attendance,
          mapped_status: mapped
        }
      end
    end
    { add: add, conflicts: conflicts, unchanged: unchanged }
  end

  validates :name, presence: true
  validate :ends_at_after_starts_at

  # Optional duration in minutes selected from the form. When present it
  # computes ends_at from starts_at; it is never stored.
  attr_accessor :duration_minutes

  # Split date ("2026-10-10") and time ("18:15") fields from the form,
  # composed into starts_at below; never stored separately. ends_at is
  # always derived from starts_at plus duration_minutes.
  attr_accessor :start_date, :start_time

  before_validation :compose_datetime_fields
  before_validation :apply_duration_minutes, if: -> { duration_minutes.present? }

  scope :upcoming, -> { where(ends_at: Time.current..).order(:starts_at) }
  scope :past, -> { where(ends_at: ...Time.current).order(starts_at: :desc) }

  def past?
    ends_at.present? && ends_at < Time.current
  end

  def scheduled?
    starts_at.present?
  end

  def covers?(content)
    return false if content.nil? || id.nil? || content.id.nil?

    ids = [ content.id ]
    return unit_coverages.exists?(content_id: ids) if content.level?
    return false unless content.parent_id

    ids << content.parent_id
    return unit_coverages.exists?(content_id: ids) if content.section?

    grandparent_id =
      if content.parent&.parent_id
        content.parent.parent_id
      else
        Content.where(id: content.parent_id).pick(:parent_id)
      end
    ids << grandparent_id if grandparent_id

    unit_coverages.exists?(content_id: ids.compact)
  end

  def self.compose_datetime(date, time)
    return nil if date.blank? || time.blank?

    hour, minute = time.to_s.split(":")
    return nil if hour.blank? || minute.blank?

    parsed = Date.iso8601(date.to_s)
    Time.zone.local(parsed.year, parsed.month, parsed.day, hour.to_i, minute.to_i)
  rescue Date::Error, ArgumentError
    nil
  end

  private

  def compose_datetime_fields
    self.starts_at = self.class.compose_datetime(start_date, start_time) if datetime_parts_present?
  end

  def datetime_parts_present?
    [ start_date, start_time ].any?(&:present?)
  end

  def apply_duration_minutes
    minutes = duration_minutes.to_i
    return if minutes <= 0 || starts_at.blank?

    self.ends_at = starts_at + minutes.minutes
  end

  def ends_at_after_starts_at
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, :after_start_time) if ends_at <= starts_at
  end
end
