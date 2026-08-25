class JuleicaProgressCalculator
  Result = Data.define(:requirement, :required_hours, :earned_hours) do
    def remaining_hours
      [ required_hours - earned_hours, 0 ].max
    end

    def completed?
      earned_hours >= required_hours
    end

    def partial?
      !completed? && earned_hours.positive?
    end
  end

  def initialize(user)
    @user = user
  end

  def call
    JuleicaRequirement.order(:name).map do |requirement|
      Result.new(requirement, requirement.required_hours, earned_hours_by_requirement.fetch(requirement.id, 0))
    end
  end

  def self.recommended_upcoming_courses(user)
    missing_requirement_ids = new(user).call.reject(&:completed?).map { |result| result.requirement.id }
    return Course.none if missing_requirement_ids.empty?

    Course.upcoming
          .joins(:course_requirements)
          .where(course_requirements: { juleica_requirement_id: missing_requirement_ids })
          .where.not(id: user.course_attendances.attended.select(:course_id))
          .distinct
          .order(:starts_at)
  end

  def credits
    CourseRequirement
      .joins(course: :course_attendances)
      .where(course_attendances: { user_id: @user.id, status: :attended })
      .includes(:juleica_requirement, course: :organization)
      .order("courses.starts_at")
  end

  private

  attr_reader :user

  def earned_hours_by_requirement
    @earned_hours_by_requirement ||=
      user.course_attendances
          .where(status: :attended)
          .joins(course: :course_requirements)
          .group("course_requirements.juleica_requirement_id")
          .sum("course_requirements.hours")
  end
end
