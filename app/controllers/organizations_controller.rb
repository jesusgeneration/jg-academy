class OrganizationsController < BaseController
  before_action :set_organization, only: %i[show edit update destroy]

  def index
    authorize Organization
    @organizations = policy_scope(Organization).order(:name)
  end

  def show
    authorize @organization
    @memberships = @organization.organization_memberships.includes(:user).order("users.email")
    @courses = @organization.courses.order(starts_at: :desc)
  end

  def new
    @organization = Organization.new
    authorize @organization
  end

  def create
    @organization = Organization.new(organization_params)
    authorize @organization
    if @organization.save
      redirect_to organizations_path, notice: "Organization was successfully created."
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
      redirect_to organizations_path, notice: "Organization was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @organization
    if @organization.destroy
      redirect_to organizations_path, notice: "Organization was successfully deleted."
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
