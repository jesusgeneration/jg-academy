require "rails_helper"

RSpec.describe CourseRequirement do
  describe "validations" do
    it "connects a course with a juleica requirement" do
      course_requirement = build(:course_requirement)

      expect(course_requirement).to be_valid
    end

    it "prevents duplicate course/requirement relationships" do
      existing = create(:course_requirement)
      duplicate = build(:course_requirement, course: existing.course, juleica_requirement: existing.juleica_requirement)

      expect(duplicate).not_to be_valid
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "requires positive hours" do
      expect(build(:course_requirement, hours: 0)).not_to be_valid
      expect(build(:course_requirement, hours: -1)).not_to be_valid
    end

    it "rejects zero or negative hours at the database level" do
      course_requirement = create(:course_requirement)

      expect {
        course_requirement.update_column(:hours, 0)
      }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "many-to-many coverage" do
    it "allows a course to cover multiple requirements" do
      course = create(:course)
      create(:course_requirement, course: course, hours: 4)
      create(:course_requirement, course: course, hours: 2)

      expect(course.course_requirements.count).to eq(2)
      expect(course.juleica_requirements.count).to eq(2)
    end

    it "allows a requirement to be covered by multiple courses" do
      requirement = create(:juleica_requirement)
      create(:course_requirement, juleica_requirement: requirement)
      create(:course_requirement, juleica_requirement: requirement)

      expect(requirement.courses.count).to eq(2)
    end

    it "supports different hours per requirement within one course" do
      course = create(:course)
      group_leadership = create(:juleica_requirement, name: "Group Leadership")
      legal_foundations = create(:juleica_requirement, name: "Legal Foundations")
      create(:course_requirement, course: course, juleica_requirement: group_leadership, hours: 4)
      create(:course_requirement, course: course, juleica_requirement: legal_foundations, hours: 2)

      expect(course.course_requirements.find_by(juleica_requirement: group_leadership).hours).to eq(4)
      expect(course.course_requirements.find_by(juleica_requirement: legal_foundations).hours).to eq(2)
    end
  end
end
