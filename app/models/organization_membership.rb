class OrganizationMembership < ApplicationRecord
  belongs_to :user
  belongs_to :organization

  enum :role, { member: 0, organiser: 1 }

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :organization_id }

  scope :organisers, -> { where(role: :organiser) }
end
