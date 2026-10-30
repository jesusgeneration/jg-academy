class DashboardsController < BaseController
  def show
    unless current_user.staff?
      redirect_to user_path(current_user)
      return
    end

    @user_count = User.count
    @upcoming_unit_count = Unit.upcoming.count
    @recent_units = Unit.includes(program: :organization).order(created_at: :desc).limit(5)
    program_ids =
      Program
        .joins(:units)
        .where(units: { ends_at: Time.current.. })
        .group("programs.id")
        .order("MIN(units.starts_at) ASC")
        .limit(5)
        .pluck("programs.id")
    @recent_programs =
      Program.includes(:organization, :units).where(id: program_ids).to_a.sort_by do |program|
        program_ids.index(program.id)
      end
  end
end
