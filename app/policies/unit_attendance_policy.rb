class UnitAttendancePolicy < ApplicationPolicy
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
    admin? || organises_organization?(record.unit&.program&.organization_id)
  end
end
