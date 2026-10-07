class Organization < ApplicationRecord
  has_many :organization_memberships, dependent: :destroy
  has_many :users, through: :organization_memberships

  has_many :programs, dependent: :restrict_with_error
  has_many :units, through: :programs

  validates :name, presence: true
end
