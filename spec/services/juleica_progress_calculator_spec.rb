require "rails_helper"

RSpec.describe JuleicaProgressCalculator do
  subject(:calculator) { described_class.new(user) }

  let(:user) { create(:user) }
  let(:group_leadership) { create(:juleica_requirement, name: "Group Leadership", required_hours: 8) }

  def result_for(requirement)
    described_class.new(user).call.find { |result| result.requirement.id == requirement.id }
  end

  describe "#call" do
    context "with no attendance" do
      it "reports 0 hours as incomplete" do
        result = result_for(group_leadership)

        aggregate_failures do
          expect(result.earned_hours).to eq(0)
          expect(result.remaining_hours).to eq(8)
          expect(result.completed?).to be(false)
          expect(result.partial?).to be(false)
        end
      end
    end

    context "with partial progress" do
      it "reports 4 / 8 with 4 hours remaining" do
        course = create(:course)
        create(:course_requirement, course: course, juleica_requirement: group_leadership, hours: 4)
        create(:course_attendance, :attended, course: course, user: user)

        result = result_for(group_leadership)

        aggregate_failures do
          expect(result.earned_hours).to eq(4)
          expect(result.remaining_hours).to eq(4)
          expect(result.completed?).to be(false)
          expect(result.partial?).to be(true)
        end
      end
    end

    context "when the requirement is exactly fulfilled" do
      it "reports complete" do
        course = create(:course)
        create(:course_requirement, course: course, juleica_requirement: group_leadership, hours: 8)
        create(:course_attendance, :attended, course: course, user: user)

        result = result_for(group_leadership)

        aggregate_failures do
          expect(result.earned_hours).to eq(8)
          expect(result.remaining_hours).to eq(0)
          expect(result).to be_completed
        end
      end
    end

    context "when more than enough hours are earned" do
      it "caps remaining hours at zero" do
        course = create(:course)
        create(:course_requirement, course: course, juleica_requirement: group_leadership, hours: 10)
        create(:course_attendance, :attended, course: course, user: user)

        result = result_for(group_leadership)

        aggregate_failures do
          expect(result.earned_hours).to eq(10)
          expect(result.remaining_hours).to eq(0)
          expect(result).to be_completed
        end
      end
    end

    context "with accumulation across multiple courses" do
      it "sums hours from both courses" do
        course_a = create(:course, name: "Course A")
        course_b = create(:course, name: "Course B")
        create(:course_requirement, course: course_a, juleica_requirement: group_leadership, hours: 4)
        create(:course_requirement, course: course_b, juleica_requirement: group_leadership, hours: 4)
        create(:course_attendance, :attended, course: course_a, user: user)
        create(:course_attendance, :attended, course: course_b, user: user)

        result = result_for(group_leadership)

        expect(result.earned_hours).to eq(8)
        expect(result).to be_completed
      end
    end

    context "with different attendance statuses" do
      it "only counts attended" do
        registered_course = create(:course)
        cancelled_course = create(:course)
        no_show_course = create(:course)
        attended_course = create(:course)
        [ registered_course, cancelled_course, no_show_course, attended_course ].each do |course|
          create(:course_requirement, course: course, juleica_requirement: group_leadership, hours: 2)
        end
        create(:course_attendance, course: registered_course, user: user)
        create(:course_attendance, :cancelled, course: cancelled_course, user: user)
        create(:course_attendance, :no_show, course: no_show_course, user: user)
        create(:course_attendance, :attended, course: attended_course, user: user)

        result = result_for(group_leadership)

        expect(result.earned_hours).to eq(2)
      end
    end

    it "does not count other users' attendance" do
      course = create(:course)
      create(:course_requirement, course: course, juleica_requirement: group_leadership, hours: 8)
      other_user = create(:user)
      create(:course_attendance, :attended, course: course, user: other_user)

      result = result_for(group_leadership)

      expect(result.earned_hours).to eq(0)
    end

    it "ignores courses that do not cover the requirement" do
      unrelated_course = create(:course)
      create(:course_requirement,
             course: unrelated_course,
             juleica_requirement: create(:juleica_requirement, name: "Child Protection"),
             hours: 6)
      create(:course_attendance, :attended, course: unrelated_course, user: user)

      result = result_for(group_leadership)

      expect(result.earned_hours).to eq(0)
    end
  end

  describe "central domain scenario" do
    it "goes from incomplete to complete when the second attendance is marked" do
      course_a = create(:course, name: "Course A")
      course_b = create(:course, name: "Course B")
      create(:course_requirement, course: course_a, juleica_requirement: group_leadership, hours: 4)
      create(:course_requirement, course: course_b, juleica_requirement: group_leadership, hours: 4)

      create(:course_attendance, :attended, course: course_a, user: user)
      create(:course_attendance, course: course_b, user: user)

      partial_result = result_for(group_leadership)
      expect(partial_result.earned_hours).to eq(4)
      expect(partial_result).not_to be_completed

      attendance_b = CourseAttendance.find_by!(user: user, course: course_b)
      attendance_b.update!(status: :attended)

      complete_result = result_for(group_leadership)
      expect(complete_result.earned_hours).to eq(8)
      expect(complete_result.remaining_hours).to eq(0)
      expect(complete_result).to be_completed
    end
  end

  describe "#credits" do
    it "traces earned hours back to individual course attendances" do
      course_a = create(:course, name: "Course A")
      course_b = create(:course, name: "Course B")
      create(:course_requirement, course: course_a, juleica_requirement: group_leadership, hours: 4)
      create(:course_requirement, course: course_b, juleica_requirement: group_leadership, hours: 4)
      create(:course_attendance, :attended, course: course_a, user: user)

      credits = calculator.credits

      expect(credits.map { |credit| credit.course.name }).to contain_exactly("Course A")
      expect(credits.sum(&:hours)).to eq(4)
    end
  end

  describe ".recommended_upcoming_courses" do
    let(:youth_methods) { create(:juleica_requirement, name: "Youth Work Methods", required_hours: 8) }

    before do
      completed_course = create(:course, name: "Completed Course")
      create(:course_requirement, course: completed_course, juleica_requirement: group_leadership, hours: 10)
      create(:course_attendance, :attended, course: completed_course, user: user)
    end

    it "suggests future courses covering missing requirements" do
      helpful = create(:course, name: "Youth Work Weekend", starts_at: 1.week.from_now)
      create(:course_requirement, course: helpful, juleica_requirement: youth_methods, hours: 6)

      suggestions = described_class.recommended_upcoming_courses(user)

      expect(suggestions).to contain_exactly(helpful)
    end

    it "excludes past and already-attended courses" do
      past = create(:course, :past)
      attended = create(:course, starts_at: 2.weeks.from_now)
      registered = create(:course, starts_at: 2.weeks.from_now + 1.day)
      fresh = create(:course, starts_at: 3.weeks.from_now)
      create(:course_requirement, course: past, juleica_requirement: youth_methods, hours: 2)
      create(:course_requirement, course: attended, juleica_requirement: youth_methods, hours: 2)
      create(:course_requirement, course: registered, juleica_requirement: youth_methods, hours: 4)
      create(:course_requirement, course: fresh, juleica_requirement: youth_methods, hours: 4)
      create(:course_attendance, :attended, course: past, user: user)
      create(:course_attendance, :attended, course: attended, user: user)
      create(:course_attendance, course: registered, user: user)

      suggestions = described_class.recommended_upcoming_courses(user)

      expect(suggestions).to contain_exactly(registered, fresh)
    end

    it "returns nothing when all requirements are completed" do
      course = create(:course)
      create(:course_requirement, course: course, juleica_requirement: youth_methods, hours: 10)
      create(:course_attendance, :attended, course: course, user: user)

      expect(described_class.recommended_upcoming_courses(user)).to be_empty
    end
  end
end
