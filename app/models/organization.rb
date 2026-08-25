class Organization < ApplicationRecord
  has_many :organization_memberships, dependent: :destroy
  has_many :users, through: :organization_memberships

  has_many :courses, dependent: :restrict_with_error

  validates :name, presence: true
end
