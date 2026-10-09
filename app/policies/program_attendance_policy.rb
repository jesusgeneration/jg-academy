class ProgramAttendancePolicy < ApplicationPolicy
  def create?
    manage?
  end

  def update?
    manage?
  end

  def destroy?
    manage?
  end

  private

  def manage?
    admin? || organises_organization?(record.program&.organization_id)
  end
end
