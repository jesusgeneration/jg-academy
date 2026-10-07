class Program < ApplicationRecord
  belongs_to :organization

  has_many :units, dependent: :restrict_with_error

  enum :kind, {
    schooling: 0,
    freizeit: 1
  }

  validates :name, presence: true
  validates :kind, presence: true
end
