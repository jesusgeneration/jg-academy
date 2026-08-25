require "rails_helper"

RSpec.describe CourseAttendance do
  describe "validations" do
    it "allows a user to attend a course" do
      attendance = build(:course_attendance)

      expect(attendance).to be_valid
    end

    it "prevents duplicate attendance for the same course" do
      existing = create(:course_attendance)
      duplicate = build(:course_attendance, user: existing.user, course: existing.course)

      expect(duplicate).not_to be_valid
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "defaults to registered" do
      expect(described_class.new.status).to eq("registered")
    end
  end

  describe "status enum" do
    it "defines all statuses" do
      expect(CourseAttendance.statuses).to eq(
        "registered" => 0,
        "attended" => 1,
        "cancelled" => 2,
        "no_show" => 3
      )
    end
  end

  describe "associations" do
    it "belongs to user and course" do
      association = described_class.reflect_on_association(:user)
      course_association = described_class.reflect_on_association(:course)

      expect(association.macro).to eq(:belongs_to)
      expect(course_association.macro).to eq(:belongs_to)
    end
  end
end
