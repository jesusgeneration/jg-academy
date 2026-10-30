class User < ApplicationRecord
  LOCALES = %w[en de].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  enum :role, { user: 0, admin: 1 }

  has_many :organization_memberships, dependent: :destroy
  has_many :organizations, through: :organization_memberships
  has_many :organiser_memberships, -> { where(role: :organiser) }, class_name: "OrganizationMembership"
  has_many :organised_organizations, through: :organiser_memberships, source: :organization

  accepts_nested_attributes_for :organization_memberships, allow_destroy: true,
    reject_if: ->(attrs) { attrs["role"].blank? && attrs["id"].blank? }

  has_many :unit_attendances, dependent: :destroy
  has_many :units, through: :unit_attendances

  scope :eligible_instructors, -> {
    where(role: :admin)
      .or(where(id: OrganizationMembership.organisers.select(:user_id)))
      .distinct.order(:email)
  }

  validates :role, presence: true
  validates :locale, presence: true, inclusion: { in: LOCALES }

  before_validation :normalize_locale

  def organiser?
    organised_organizations.any?
  end

  def eligible_instructor?
    admin? || organiser?
  end

  def staff?
    admin? || organiser?
  end

  def organises?(organization_or_id)
    organization_id = organization_or_id.is_a?(Organization) ? organization_or_id.id : organization_or_id
    organised_organizations.exists?(organization_id)
  end

  private

  def normalize_locale
    self.locale = "de" if locale.blank?
    self.locale = locale.to_s
  end
end
