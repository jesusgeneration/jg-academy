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

  # Changing the instructor once participants attended is restricted to
  # the current instructor or an admin. Uses instructor_id_was so the
  # check targets the previously assigned instructor, not the new one.
  def change_instructor?
    return true unless record.unit_attendances.attended.exists?
    return true if admin?

    record.instructor_id_was.present? && record.instructor_id_was == user.id
  end

  # Roster visibility for a specific unit.
  def view_attendees?
    update?
  end

  # Bulk copy of the program roster onto this unit.
  def inherit_attendances?
    update?
  end

  # Whether the attendee summary column may appear on the units index.
  def view_attendance_summary?
    admin? || organiser_anywhere?
  end

  class Scope < ApplicationPolicy::Scope
  end
end
