class UserPolicy < ApplicationPolicy
  def show?
    admin? || record == user
  end

  def confirm?
    admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.admin? ? scope.all : scope.where(id: user.id)
    end
  end
end
