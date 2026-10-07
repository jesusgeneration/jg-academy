class UnitAttendancesController < BaseController
  before_action :set_unit

  def create
    @attendance = @unit.unit_attendances.build(user_id: attendance_params[:user_id], status: :registered)
    authorize @attendance
    if @attendance.save
      redirect_to @unit, notice: "#{@attendance.user.email} was registered for this unit."
    else
      redirect_to @unit, alert: @attendance.errors.full_messages.to_sentence
    end
  end

  def update
    @attendance = @unit.unit_attendances.find(params[:id])
    authorize @attendance
    if @attendance.update(attendance_params)
      redirect_to @unit, notice: "Attendance was updated."
    else
      redirect_to @unit, alert: @attendance.errors.full_messages.to_sentence
    end
  end

  def destroy
    @attendance = @unit.unit_attendances.find(params[:id])
    authorize @attendance
    @attendance.destroy
    redirect_to @unit, notice: "Attendance record was removed."
  end

  private

  def set_unit
    @unit = Unit.find(params[:unit_id])
  end

  def attendance_params
    params.require(:unit_attendance).permit(:user_id, :status)
  end
end
