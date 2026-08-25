class DashboardsController < BaseController
  def show
    unless current_user.staff?
      redirect_to user_path(current_user)
      return
    end

    @user_count = User.count
    @upcoming_course_count = Course.upcoming.count
    @requirement_count = JuleicaRequirement.count
    @recent_courses = Course.includes(:organization).order(created_at: :desc).limit(5)
    @close_users = users_close_to_completion
  end

  private

  def users_close_to_completion(limit = 8)
    User.find_each.filter_map do |user|
      progress = JuleicaProgressCalculator.new(user).call
      best = progress.max_by { |result| result.earned_hours / result.required_hours }
      next if best.nil? || best.completed? || best.earned_hours.zero?

      [ user, best ]
    end.sort_by { |_, best| -(best.earned_hours / best.required_hours) }.first(limit)
  end
end
