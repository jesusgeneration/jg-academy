class JuleicaRequirementsController < BaseController
  before_action :set_juleica_requirement, only: %i[show edit update destroy]

  def index
    authorize JuleicaRequirement
    @juleica_requirements = policy_scope(JuleicaRequirement).order(:name)
  end

  def show
    authorize @juleica_requirement
    @courses = @juleica_requirement.courses.order(starts_at: :desc)
  end

  def new
    @juleica_requirement = JuleicaRequirement.new
    authorize @juleica_requirement
  end

  def create
    @juleica_requirement = JuleicaRequirement.new(juleica_requirement_params)
    authorize @juleica_requirement
    if @juleica_requirement.save
      redirect_to juleica_requirements_path, notice: "Juleica requirement was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @juleica_requirement
  end

  def update
    authorize @juleica_requirement
    if @juleica_requirement.update(juleica_requirement_params)
      redirect_to juleica_requirements_path, notice: "Juleica requirement was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @juleica_requirement
    if @juleica_requirement.destroy
      redirect_to juleica_requirements_path, notice: "Juleica requirement was successfully deleted."
    else
      redirect_to juleica_requirements_path, alert: @juleica_requirement.errors.full_messages.to_sentence
    end
  end

  private

  def set_juleica_requirement
    @juleica_requirement = JuleicaRequirement.find(params[:id])
  end

  def juleica_requirement_params
    params.require(:juleica_requirement).permit(:name, :description, :required_hours)
  end
end
