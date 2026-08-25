class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  enum :role, { user: 0, admin: 1 }

  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships
  has_many :organiser_memberships, -> { where(role: :organiser) }, class_name: "OrganizationMembership"
  has_many :organised_organizations, through: :organiser_memberships, source: :organization

  accepts_nested_attributes_for :organization_memberships, allow_destroy: true,
    reject_if: ->(attrs) { attrs["role"].blank? && attrs["id"].blank? }

  has_many :course_attendances, dependent: :destroy
  has_many :courses, through: :course_attendances

  validates :role, presence: true

  def juleica_progress
    JuleicaProgressCalculator.new(self).call
  end

  def recommended_upcoming_courses
    JuleicaProgressCalculator.recommended_upcoming_courses(self)
  end

  def organiser?
    organised_organizations.any?
  end

  def staff?
    admin? || organiser?
  end

  def organises?(organization_or_id)
    organization_id = organization_or_id.is_a?(Organization) ? organization_or_id.id : organization_or_id
    organised_organizations.exists?(organization_id)
  end
end
