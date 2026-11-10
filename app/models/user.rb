class User < ApplicationRecord
  class GoogleLinkConflict < StandardError; end

  LOCALES = %w[en de].freeze

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

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
  validates :uid, uniqueness: { scope: :provider }, allow_blank: true
  validate :provider_and_uid_together

  before_validation :normalize_locale

  def self.from_google_oauth2(auth)
    find_by(provider: auth.provider, uid: auth.uid) || find_or_link_google_user(auth)
  rescue ActiveRecord::RecordNotUnique
    find_by(provider: auth.provider, uid: auth.uid) || raise(GoogleLinkConflict)
  end

  def self.find_or_link_google_user(auth)
    user = find_by(email: auth.info.email.to_s.downcase)

    if user
      user.link_google!(auth)
    else
      create_from_google_oauth2!(auth)
    end
  end
  private_class_method :find_or_link_google_user

  def self.create_from_google_oauth2!(auth)
    create!(
      email: auth.info.email.to_s.downcase,
      provider: auth.provider,
      uid: auth.uid,
      password: Devise.friendly_token[0, 32],
      confirmed_at: Time.current
    )
  end
  private_class_method :create_from_google_oauth2!

  def google_linked?
    provider == GoogleOauth::PROVIDER && uid.present?
  end

  def link_google!(auth)
    if provider.present? && (provider != auth.provider || uid != auth.uid)
      raise GoogleLinkConflict
    end

    update!(
      provider: auth.provider,
      uid: auth.uid,
      confirmed_at: confirmed_at || Time.current
    )
    self
  end

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

  def provider_and_uid_together
    return if provider.blank? && uid.blank?

    errors.add(:provider, :blank) if provider.blank?
    errors.add(:uid, :blank) if uid.blank?
  end
end
