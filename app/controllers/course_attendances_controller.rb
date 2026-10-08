class CourseAttendancesController < BaseController
  before_action :set_course

  def create
    @attendance = @course.course_attendances.build(user_id: attendance_params[:user_id], status: :registered)
    authorize @attendance
    if @attendance.save
      redirect_to @course, notice: "#{@attendance.user.email} wurde für diesen Kurs angemeldet."
    else
      redirect_to @course, alert: @attendance.errors.full_messages.to_sentence
    end
  end

  def update
    @attendance = @course.course_attendances.find(params[:id])
    authorize @attendance
    if @attendance.update(attendance_params)
      redirect_to @course, notice: "Anwesenheit wurde aktualisiert."
    else
      redirect_to @course, alert: @attendance.errors.full_messages.to_sentence
    end
  end

  def destroy
    @attendance = @course.course_attendances.find(params[:id])
    authorize @attendance
    @attendance.destroy
    redirect_to @course, notice: "Anwesenheitseintrag wurde entfernt."
  end

  private

  def set_course
    @course = Course.find(params[:course_id])
  end

  def attendance_params
    params.require(:course_attendance).permit(:user_id, :status)
  end
end
