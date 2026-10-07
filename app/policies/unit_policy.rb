class UnitPolicy < ApplicationPolicy
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
    admin? || organises_organization?(record.program&.organization_id)
  end

  def destroy?
    update?
  end

  # Roster visibility for a specific unit.
  def view_attendees?
    update?
  end

  # Whether the attendee summary column may appear on the units index.
  def view_attendance_summary?
    admin? || organiser_anywhere?
  end

  class Scope < ApplicationPolicy::Scope
  end
end
