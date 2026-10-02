require "rails_helper"

RSpec.describe "Course#covers?" do
  def build_tree
    level1 = create(:content, :level, title: "Level 1", position: 0)
    level2 = create(:content, :level, title: "Level 2", position: 1)

    section11 = create(:content, :section, title: "Level 1.1", parent: level1, position: 0)
    section12 = create(:content, :section, title: "Level 1.2", parent: level1, position: 1)
    section21 = create(:content, :section, title: "Level 2.1", parent: level2, position: 0)
    section22 = create(:content, :section, title: "Level 2.2", parent: level2, position: 1)

    detail111 = create(:content, :detail, title: "Detail 1.1.1", parent: section11, position: 0)
    detail112 = create(:content, :detail, title: "Detail 1.1.2", parent: section11, position: 1)
    detail113 = create(:content, :detail, title: "Detail 1.1.3", parent: section11, position: 2)
    detail121 = create(:content, :detail, title: "Detail 1.2.1", parent: section12, position: 0)
    detail122 = create(:content, :detail, title: "Detail 1.2.2", parent: section12, position: 1)
    detail211 = create(:content, :detail, title: "Detail 2.1.1", parent: section21, position: 0)
    detail212 = create(:content, :detail, title: "Detail 2.1.2", parent: section21, position: 1)
    detail221 = create(:content, :detail, title: "Detail 2.2.1", parent: section22, position: 0)
    detail222 = create(:content, :detail, title: "Detail 2.2.2", parent: section22, position: 1)

    {
      level1:, level2:,
      section11:, section12:, section21:, section22:,
      detail111:, detail112:, detail113:,
      detail121:, detail122:,
      detail211:, detail212:,
      detail221:, detail222:
    }
  end

  describe "Course 1 covering Level 1 and Detail 2.2.1" do
    it "covers the level subtree plus the single detail" do
      tree = build_tree
      course = create(:course)
      create(:course_coverage, course: course, content: tree[:level1])
      create(:course_coverage, course: course, content: tree[:detail221])

      aggregate_failures do
        expect(course.covers?(tree[:level1])).to be(true)
        expect(course.covers?(tree[:section11])).to be(true)
        expect(course.covers?(tree[:detail111])).to be(true)
        expect(course.covers?(tree[:detail112])).to be(true)
        expect(course.covers?(tree[:detail113])).to be(true)
        expect(course.covers?(tree[:section12])).to be(true)
        expect(course.covers?(tree[:detail121])).to be(true)
        expect(course.covers?(tree[:detail122])).to be(true)

        expect(course.covers?(tree[:level2])).to be(false)
        expect(course.covers?(tree[:section21])).to be(false)
        expect(course.covers?(tree[:detail211])).to be(false)
        expect(course.covers?(tree[:detail212])).to be(false)
        expect(course.covers?(tree[:section22])).to be(false)
        expect(course.covers?(tree[:detail221])).to be(true)
        expect(course.covers?(tree[:detail222])).to be(false)
      end
    end
  end

  describe "Course 2 covering Detail 1.1.3, Detail 1.2.2 and Level 2.1" do
    it "covers exactly those items and the Level 2.1 subtree" do
      tree = build_tree
      course = create(:course)
      create(:course_coverage, course: course, content: tree[:detail113])
      create(:course_coverage, course: course, content: tree[:detail122])
      create(:course_coverage, course: course, content: tree[:section21])

      aggregate_failures do
        expect(course.covers?(tree[:detail113])).to be(true)
        expect(course.covers?(tree[:detail122])).to be(true)
        expect(course.covers?(tree[:section21])).to be(true)
        expect(course.covers?(tree[:detail211])).to be(true)
        expect(course.covers?(tree[:detail212])).to be(true)

        expect(course.covers?(tree[:level1])).to be(false)
        expect(course.covers?(tree[:section11])).to be(false)
        expect(course.covers?(tree[:detail111])).to be(false)
        expect(course.covers?(tree[:section22])).to be(false)
        expect(course.covers?(tree[:detail221])).to be(false)
        expect(course.covers?(tree[:detail222])).to be(false)
      end
    end
  end

  describe "edge cases" do
    it "covers a directly linked section and its details but not siblings or ancestors" do
      tree = build_tree
      course = create(:course)
      create(:course_coverage, course: course, content: tree[:section11])

      aggregate_failures do
        expect(course.covers?(tree[:section11])).to be(true)
        expect(course.covers?(tree[:detail111])).to be(true)
        expect(course.covers?(tree[:detail112])).to be(true)
        # Sibling section and its details are not covered.
        expect(course.covers?(tree[:section12])).to be(false)
        expect(course.covers?(tree[:detail121])).to be(false)
        # Ancestor level is not covered by a section link.
        expect(course.covers?(tree[:level1])).to be(false)
        expect(course.covers?(nil)).to be(false)
      end
    end

    it "covers only the linked detail" do
      tree = build_tree
      course = create(:course)
      create(:course_coverage, course: course, content: tree[:detail111])

      aggregate_failures do
        expect(course.covers?(tree[:detail111])).to be(true)
        expect(course.covers?(tree[:detail112])).to be(false)
        expect(course.covers?(tree[:section11])).to be(false)
        expect(course.covers?(tree[:level1])).to be(false)
      end
    end
  end
end
