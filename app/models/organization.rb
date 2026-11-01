class Organization < ApplicationRecord
  has_many :organization_memberships, dependent: :destroy
  has_many :users, through: :organization_memberships

  has_many :programs, dependent: :restrict_with_error
  has_many :units, through: :programs

  validates :name, presence: true

  # Default overview ordering: most programs first, then most members,
  # then name for stability. Counts need DISTINCT because joining both
  # associations multiplies their rows.
  scope :with_counts, -> {
    left_joins(:programs, :users)
      .select(
        "organizations.*, " \
        "COUNT(DISTINCT programs.id) AS programs_count, " \
        "COUNT(DISTINCT users.id) AS members_count"
      )
      .group(:id)
  }
  scope :ordered_by_activity, -> {
    with_counts.order(programs_count: :desc, members_count: :desc, name: :asc)
  }
end
