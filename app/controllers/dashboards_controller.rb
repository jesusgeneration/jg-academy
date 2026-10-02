class DashboardsController < BaseController
  def show
    unless current_user.staff?
      redirect_to user_path(current_user)
      return
    end

    @user_count = User.count
    @upcoming_course_count = Course.upcoming.count
    @recent_courses = Course.includes(:organization).order(created_at: :desc).limit(5)
  end
end
