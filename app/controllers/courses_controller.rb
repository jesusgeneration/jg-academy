class CoursesController < BaseController
  before_action :set_course, only: %i[show edit update destroy]

  def index
    authorize Course
    scope = policy_scope(Course).includes(:organization, :course_attendances)
    @tab = %w[upcoming past all].include?(params[:tab]) ? params[:tab] : "upcoming"
    @courses = case @tab
    when "past" then scope.past
    when "all" then scope.order(starts_at: :desc)
    else scope.upcoming
    end
    @show_attendance_summary = policy(Course).view_attendance_summary?
  end

  def show
    authorize @course
    @course_requirements = @course.course_requirements.includes(:juleica_requirement)
    @attendances = @course.course_attendances.includes(:user).order("users.email")
    return unless policy(@course).update?

    @attendee_management = true
    @registrable_users = User.order(:email) - @course.users
  end

  def new
    @course = Course.new(organization: permitted_organizations.first)
    authorize @course
    @permitted_organizations = permitted_organizations
    @course.course_requirements.build
  end

  def create
    @course = Course.new(course_params)
    authorize @course
    ensure_permitted_organization
    if @course.save
      redirect_to @course, notice: "Course was successfully created."
    else
      prepare_form
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @course
    prepare_form
    @course.course_requirements.build
  end

  def update
    authorize @course
    @course.assign_attributes(course_params)
    ensure_permitted_organization
    if @course.save
      redirect_to @course, notice: "Course was successfully updated."
    else
      prepare_form
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @course
    @course.destroy
    redirect_to courses_path, notice: "Course was successfully deleted."
  end

  private

  def set_course
    @course = Course.find(params[:id])
  end

  def course_params
    params.require(:course).permit(:name, :description, :starts_at, :ends_at, :location, :organization_id,
      course_requirements_attributes: %i[id juleica_requirement_id hours _destroy])
  end

  def permitted_organizations
    current_user.admin? ? Organization.all : current_user.organised_organizations.order(:name)
  end

  # Defense-in-depth: non-admins may only assign organizations they organise.
  def ensure_permitted_organization
    return if current_user.admin?

    candidate = @course.organization_id&.to_i
    @course.organization_id = permitted_organizations.exists?(candidate) ? candidate : permitted_organizations.pick(:id)
  end

  def prepare_form
    @permitted_organizations = permitted_organizations
    @course.course_requirements.build unless @course.course_requirements.any?(&:new_record?)
  end
end
