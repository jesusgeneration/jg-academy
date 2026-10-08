class CourseCoveragesController < BaseController
  before_action :set_course

  def create
    authorize @course, :update?
    @coverage = @course.course_coverages.build(content_id: coverage_params[:content_id])
    if @coverage.save
      redirect_to @course, notice: "#{@coverage.content.title} wird jetzt von diesem Kurs abgedeckt."
    else
      redirect_to @course, alert: @coverage.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @course, :update?
    @coverage = @course.course_coverages.find(params[:id])
    @coverage.destroy
    redirect_to @course, notice: "Abdeckung wurde entfernt."
  end

  private

  def set_course
    @course = Course.find(params[:course_id])
  end

  def coverage_params
    params.require(:course_coverage).permit(:content_id)
  end
end
