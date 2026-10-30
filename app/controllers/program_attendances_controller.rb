class ProgramAttendancesController < BaseController
  before_action :set_program

  def create
    @attendance = @program.program_attendances.build(user_id: attendance_params[:user_id], status: :registered)
    authorize @attendance
    if @attendance.save
      redirect_to @program, notice: t(".created", email: @attendance.user.email)
    else
      redirect_to @program, alert: @attendance.errors.full_messages.to_sentence
    end
  end

  def update
    @attendance = @program.program_attendances.find(params[:id])
    authorize @attendance
    if @attendance.update(attendance_params)
      redirect_to @program, notice: t(".updated")
    else
      redirect_to @program, alert: @attendance.errors.full_messages.to_sentence
    end
  end

  def destroy
    @attendance = @program.program_attendances.find(params[:id])
    authorize @attendance
    @attendance.destroy
    redirect_to @program, notice: t(".destroyed")
  end

  private

  def set_program
    @program = Program.find(params[:program_id])
  end

  def attendance_params
    params.require(:program_attendance).permit(:user_id, :status)
  end
end
