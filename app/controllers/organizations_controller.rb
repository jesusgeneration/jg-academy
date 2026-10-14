class OrganizationsController < BaseController
  before_action :set_organization, only: %i[show edit update destroy]

  def index
    authorize Organization
    scope = policy_scope(Organization).with_counts
    @organizations = case sort_key(%w[name programs members])
    when "name" then scope.order(name: sort_direction)
    when "programs" then scope.order(programs_count: sort_direction, name: :asc)
    when "members" then scope.order(members_count: sort_direction, name: :asc)
    else scope.order(programs_count: :desc, members_count: :desc, name: :asc)
    end
  end

  def show
    authorize @organization
    @memberships = @organization.organization_memberships.includes(:user).order("users.email")
    @programs = @organization.programs.order(:name)
  end

  def new
    @organization = Organization.new
    authorize @organization
  end

  def create
    @organization = Organization.new(organization_params)
    authorize @organization
    if @organization.save
      redirect_to organizations_path, notice: t(".created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @organization
  end

  def update
    authorize @organization
    if @organization.update(organization_params)
      redirect_to organizations_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @organization
    if @organization.destroy
      redirect_to organizations_path, notice: t(".destroyed")
    else
      redirect_to organizations_path, alert: @organization.errors.full_messages.to_sentence
    end
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name, :description)
  end
end
