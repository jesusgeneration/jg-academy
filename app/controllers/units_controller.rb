class UnitsController < BaseController
  before_action :set_unit, only: %i[show edit update destroy]

  def index
    authorize Unit
    scope = policy_scope(Unit).includes(program: :organization, unit_attendances: :user)
    @tab = %w[upcoming past all].include?(params[:tab]) ? params[:tab] : "upcoming"
    @units = case @tab
    when "past" then scope.past
    when "all" then scope.order(starts_at: :desc)
    else scope.upcoming
    end
    @show_attendance_summary = policy(Unit).view_attendance_summary?
  end

  def show
    authorize @unit
    @attendances = @unit.unit_attendances.includes(:user).order("users.email")
    return unless policy(@unit).update?

    @attendee_management = true
    @registrable_users = User.order(:email) - @unit.users
    @coverage_tree = Content.includes(children: :children).where(parent_id: nil).ordered
    @coverages_by_content_id = @unit.unit_coverages.index_by(&:content_id)
  end

  def new
    @unit = Unit.new(program: permitted_programs.first)
    authorize @unit
    @permitted_programs = permitted_programs
  end

  def create
    @unit = Unit.new(unit_params)
    authorize @unit
    ensure_permitted_program
    if @unit.save
      redirect_to @unit, notice: t(".created")
    else
      prepare_form
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @unit
    prepare_form
  end

  def update
    authorize @unit
    @unit.assign_attributes(unit_params)
    ensure_permitted_program
    if @unit.save
      redirect_to @unit, notice: t(".updated")
    else
      prepare_form
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @unit
    program = @unit.program
    @unit.destroy
    redirect_to program, notice: t(".destroyed")
  end

  private

  def set_unit
    @unit = Unit.find(params[:id])
  end

  def unit_params
    params.require(:unit).permit(:name, :description, :starts_at, :ends_at, :location, :program_id)
  end

  def permitted_programs
    if current_user.admin?
      Program.includes(:organization).order(:name)
    else
      Program.where(organization: current_user.organised_organizations).includes(:organization).order(:name)
    end
  end

  # Defense-in-depth: non-admins may only assign programs they organise.
  def ensure_permitted_program
    return if current_user.admin?

    candidate = @unit.program_id&.to_i
    @unit.program_id = permitted_programs.exists?(candidate) ? candidate : permitted_programs.pick(:id)
  end

  def prepare_form
    @permitted_programs = permitted_programs
  end
end
