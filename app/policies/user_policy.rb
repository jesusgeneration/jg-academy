class UserPolicy < ApplicationPolicy
  def show?
    admin? || record == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.admin? ? scope.all : scope.where(id: user.id)
    end
  end
end
