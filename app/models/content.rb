class Content < ApplicationRecord
  belongs_to :parent, class_name: "Content", optional: true
  has_many :children, -> { order(:position) },
    class_name: "Content", foreign_key: :parent_id,
    dependent: :restrict_with_error

  has_many :course_coverages, dependent: :destroy
  has_many :courses, through: :course_coverages

  enum :content_type, {
    level: 0,
    section: 1,
    detail: 2
  }

  validates :title, presence: true
  validates :content_type, presence: true
  validates :position, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :hierarchy_rules

  scope :ordered, -> { order(:position) }

  def ancestors
    chain = []
    current = parent
    while current
      chain << current
      current = current.parent
      break if chain.size > 2
    end
    chain
  end

  private

  # Child types from both in-memory (unsaved) and persisted records.
  # Uses `children.target` plus a direct query so validation never
  # populates the `children` association cache as a side effect.
  def child_content_types
    types = children.target.map(&:content_type)
    types |= Content.where(parent_id: id).pluck(:content_type) if persisted?
    types
  end

  def hierarchy_rules
    case content_type
    when "level"
      errors.add(:parent, "level must not have a parent") if parent.present?
      if child_content_types.include?("detail")
        errors.add(:base, "level must not have detail children")
      end
    when "section"
      if parent.nil?
        errors.add(:parent, "section requires a level parent")
      elsif !parent.level?
        errors.add(:parent, "section requires a level parent")
      end
      if child_content_types.any? { |type| type != "detail" }
        errors.add(:base, "section may only have detail children")
      end
    when "detail"
      if parent.nil?
        errors.add(:parent, "detail requires a section parent")
      elsif !parent.section?
        errors.add(:parent, "detail requires a section parent")
      end
      errors.add(:base, "detail must not have children") if child_content_types.any?
    end
  end
end
