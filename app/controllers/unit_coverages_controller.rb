class UnitCoveragesController < BaseController
  before_action :set_unit

  def create
    authorize @unit, :update?
    @coverage = @unit.unit_coverages.build(content_id: coverage_params[:content_id])
    if @coverage.save
      redirect_to @unit, notice: "#{@coverage.content.title} is now covered by this unit."
    else
      redirect_to @unit, alert: @coverage.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @unit, :update?
    @coverage = @unit.unit_coverages.find(params[:id])
    @coverage.destroy
    redirect_to @unit, notice: "Coverage was removed."
  end

  private

  def set_unit
    @unit = Unit.find(params[:unit_id])
  end

  def coverage_params
    params.require(:unit_coverage).permit(:content_id)
  end
end
