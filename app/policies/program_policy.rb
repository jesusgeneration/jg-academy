class ProgramPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    admin? || organiser_anywhere?
  end

  def update?
    admin? || organises_organization?(record.organization_id)
  end

  def destroy?
    update?
  end

  # Roster visibility for a specific program.
  def view_attendees?
    update?
  end

  class Scope < ApplicationPolicy::Scope
  end
end
