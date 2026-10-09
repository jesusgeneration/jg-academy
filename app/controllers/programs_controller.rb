class ProgramsController < BaseController
  before_action :set_program, only: %i[show edit update destroy]

  def index
    authorize Program
    @programs = policy_scope(Program).includes(:organization, :units).order(:name)
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
end
