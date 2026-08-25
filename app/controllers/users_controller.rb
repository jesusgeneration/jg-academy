class UsersController < BaseController
  before_action :set_user, only: %i[show edit update destroy]
  before_action :set_organizations, only: %i[new create edit update]

  def index
    authorize User
    @users = policy_scope(User).order(:email)
  end

  def show
    authorize @user
    @progress = JuleicaProgressCalculator.new(@user).call
    @credits_by_requirement = JuleicaProgressCalculator.new(@user).credits.group_by(&:juleica_requirement_id)
    @recommended_courses = JuleicaProgressCalculator.recommended_upcoming_courses(@user)
                                                    .includes(:organization, course_requirements: :juleica_requirement)
  end

  def new
    @user = User.new
    authorize @user
    build_membership_rows
  end

  def create
    @user = User.new(user_params)
    authorize @user
    if @user.save
      redirect_to users_path, notice: "User was successfully created."
    else
      build_membership_rows
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @user
    build_membership_rows
  end

  def update
    authorize @user
    if @user.update(user_params)
      redirect_to users_path, notice: "User was successfully updated."
    else
      build_membership_rows
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @user
    if @user == current_user
      redirect_to users_path, alert: "You cannot delete your own account."
    elsif @user.destroy
      redirect_to users_path, notice: "User was successfully deleted."
    else
      redirect_to users_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_organizations
    @organizations = Organization.order(:name)
  end

  # One membership row per organization so every organization gets a role select.
  def build_membership_rows
    existing = @user.organization_memberships.index_by(&:organization_id)
    @membership_rows = @organizations.map do |organization|
      existing[organization.id] || @user.organization_memberships.build(organization: organization)
    end
  end

  def user_params
    permitted = %i[email role password password_confirmation] +
                [ { organization_memberships_attributes: %i[id organization_id role _destroy] } ]
    user_params = params.require(:user).permit(permitted)
    normalize_membership_roles(user_params)
    if action_name == "update"
      user_params.delete(:password) if user_params[:password].blank?
      user_params.delete(:password_confirmation) if user_params[:password_confirmation].blank?
    end
    user_params
  end

  # A cleared ("Not a member") select on an existing membership destroys it.
  def normalize_membership_roles(params)
    memberships = params[:organization_memberships_attributes]
    return unless memberships

    memberships.each_value do |row|
      row[:_destroy] = "1" if row[:role].blank? && row[:id].present?
    end
  end
end
