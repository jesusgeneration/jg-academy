class UnitsController < BaseController
  before_action :set_unit, only: %i[show edit update destroy inherit_attendances apply_attendances]

  def index
    authorize Unit
    scope = policy_scope(Unit).includes(program: :organization, unit_attendances: :user)
    @tab = %w[upcoming past planned all].include?(params[:tab]) ? params[:tab] : "upcoming"
    @units = case @tab
    when "past" then scope.past
    when "planned" then scope.planned
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
    @inheritance_preview = @unit.attendance_inheritance_preview
    @program_has_attendances = @unit.program.program_attendances.exists?
  end

  def new
    @unit = Unit.new
    authorize @unit
    @permitted_programs = permitted_programs
    @eligible_instructors = User.eligible_instructors
    @coverage_tree = coverage_tree
  end

  def create
    @unit = Unit.new(unit_params)
    authorize @unit
    ensure_permitted_program
    begin
      ActiveRecord::Base.transaction do
        @unit.save!
        coverage_content_ids.each do |content_id|
          @unit.unit_coverages.create!(content_id: content_id)
        end
      end
      redirect_to @unit, notice: t(".created")
    rescue ActiveRecord::RecordInvalid
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
    authorize @unit, :change_instructor? if @unit.instructor_id_changed?
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

  def inherit_attendances
    authorize @unit, :inherit_attendances?
    @preview = @unit.attendance_inheritance_preview
  end

  def apply_attendances
    authorize @unit, :inherit_attendances?
    preview = @unit.attendance_inheritance_preview
    conflict_ids = preview[:conflicts].map { |conflict| conflict[:user].id }
    import_ids = Array(inheritance_params[:import_user_ids]).map(&:to_i) & conflict_ids
    added = 0
    resolved = 0
    ActiveRecord::Base.transaction do
      preview[:add].each do |program_attendance|
        @unit.unit_attendances.create!(
          user: program_attendance.user,
          status: Unit.inherited_status(program_attendance.status)
        )
        added += 1
      end
      import_ids.each do |user_id|
        conflict = preview[:conflicts].find { |entry| entry[:user].id == user_id }
        conflict[:unit_attendance].update!(status: conflict[:mapped_status])
        resolved += 1
      end
    end
    kept = preview[:unchanged] + preview[:conflicts].size - resolved
    redirect_to unit_path(@unit, anchor: "attendees"),
      notice: t(".inherited", added: added, kept: kept, resolved: resolved)
  end

  private

  def set_unit
    @unit = Unit.find(params[:id])
  end

  def unit_params
    params.require(:unit).permit(:name, :description, :location, :program_id, :instructor_id,
      :duration_minutes, :start_date, :start_time)
  end

  def inheritance_params
    params.permit(import_user_ids: [])
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
    @eligible_instructors = User.eligible_instructors
    @coverage_tree = coverage_tree
  end

  def coverage_tree
    Content.includes(children: :children).where(parent_id: nil).ordered
  end

  def coverage_content_ids
    ids = Array(params.permit(coverage_content_ids: [])[:coverage_content_ids]).map(&:to_i).uniq
    Content.where(id: ids).pluck(:id)
  end
end
