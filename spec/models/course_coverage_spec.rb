require "rails_helper"

RSpec.describe CourseCoverage do
  it "links a course to content" do
    expect(build(:course_coverage)).to be_valid
  end

  it "requires course and content" do
    expect(build(:course_coverage, course: nil)).not_to be_valid
    expect(build(:course_coverage, content: nil)).not_to be_valid
  end

  it "prevents duplicate course/content combinations" do
    existing = create(:course_coverage)
    duplicate = build(:course_coverage, course: existing.course, content: existing.content)

    expect(duplicate).not_to be_valid
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same content to be covered by multiple courses" do
    content = create(:content, :detail)
    create(:course_coverage, content: content)
    create(:course_coverage, content: content)

    expect(content.courses.count).to eq(2)
  end

  it "allows a course to cover multiple contents" do
    course = create(:course)
    create(:course_coverage, course: course)
    create(:course_coverage, course: course)

    expect(course.covered_contents.count).to eq(2)
  end
end
