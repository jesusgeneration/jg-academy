class ProgramsController < BaseController
  before_action :set_program, only: %i[show edit update destroy]

  def index
    authorize Program
    scope = policy_scope(Program).includes(:organization, :units)
    @tab = %w[upcoming past planned all].include?(params[:tab]) ? params[:tab] : "upcoming"
    programs = case @tab
    when "past" then scope.past
    when "planned" then scope.planned
    when "all" then scope
    else scope.upcoming
    end
    @programs = case sort_key(%w[name kind organization units])
    when "name" then programs.order(name: sort_direction)
    when "kind" then programs.order(kind: sort_direction, name: :asc)
    when "organization" then programs.joins(:organization).merge(Organization.order(name: sort_direction)).order(name: :asc)
    when "units" then sort_programs_by_unit_count(programs.to_a, sort_direction)
    else programs.order(:name)
    end
  end

  def show
    authorize @program
    @units = @program.units.order(:starts_at)
    @attendances = @program.program_attendances.includes(:user).order("users.email")
    return unless policy(@program).update?

    @attendee_management = true
    @registrable_users = User.order(:email) - @program.users
  end

  def new
    @program = Program.new(organization: permitted_organizations.first)
    authorize @program
    @permitted_organizations = permitted_organizations
  end

  def create
    @program = Program.new(program_params)
    authorize @program
    ensure_permitted_organization
    if @program.save
      redirect_to @program, notice: t(".created")
    else
      prepare_form
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @program
    prepare_form
  end

  def update
    authorize @program
    @program.assign_attributes(program_params)
    ensure_permitted_organization
    if @program.save
      redirect_to @program, notice: t(".updated")
    else
      prepare_form
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @program
    if @program.destroy
      redirect_to programs_path, notice: t(".destroyed")
    else
      redirect_to programs_path, alert: @program.errors.full_messages.to_sentence
    end
  end

  private

  def set_program
    @program = Program.find(params[:id])
  end

  def program_params
    params.require(:program).permit(:name, :description, :kind, :organization_id)
  end

  def permitted_organizations
    current_user.admin? ? Organization.all : current_user.organised_organizations.order(:name)
  end

  # Defense-in-depth: non-admins may only assign organizations they organise.
  def ensure_permitted_organization
    return if current_user.admin?

    candidate = @program.organization_id&.to_i
    @program.organization_id = permitted_organizations.exists?(candidate) ? candidate : permitted_organizations.pick(:id)
  end

  def prepare_form
    @permitted_organizations = permitted_organizations
  end

  # Units per program, counted from the preloaded association. Name breaks ties.
  def sort_programs_by_unit_count(programs, direction)
    if direction == "desc"
      programs.sort_by { |program| [ -program.units.size, program.name ] }
    else
      programs.sort_by { |program| [ program.units.size, program.name ] }
    end
  end
end
