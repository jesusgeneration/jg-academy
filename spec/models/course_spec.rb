require "rails_helper"

RSpec.describe Course do
  describe "validations" do
    it "requires a name, organization and dates" do
      expect(build(:course)).to be_valid
      expect(build(:course, name: nil)).not_to be_valid
      expect(build(:course, organization: nil)).not_to be_valid
      expect(build(:course, starts_at: nil)).not_to be_valid
      expect(build(:course, ends_at: nil)).not_to be_valid
    end

    it "rejects end before start" do
      course = build(:course, starts_at: 2.weeks.from_now, ends_at: 1.week.from_now)

      expect(course).not_to be_valid
    end
  end

  describe "scopes" do
    let!(:upcoming_course) { create(:course) }
    let!(:past_course) { create(:course, :past) }

    it ".upcoming returns courses ending in the future" do
      expect(Course.upcoming).to contain_exactly(upcoming_course)
    end

    it ".past returns courses already finished" do
      expect(Course.past).to contain_exactly(past_course)
    end
  end

  describe "associations" do
    it "destroys attendances and requirements with the course" do
      course = create(:course)
      create(:course_attendance, course: course)
      create(:course_requirement, course: course)

      expect { course.destroy }.to change(CourseAttendance, :count).by(-1)
        .and change(CourseRequirement, :count).by(-1)
    end
  end
end
