require "rails_helper"

RSpec.describe "User progress" do
  describe "GET /users/:id" do
    let(:admin) { create(:user, :admin) }
    let(:alice) { create(:user, email: "alice@example.com") }

    it "shows a user's progress to admins" do
      sign_in admin

      get user_path(alice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Juleica Progress")
    end

    it "lets participants view their own progress page" do
      sign_in alice
      requirement = create(:juleica_requirement, name: "Group Leadership", required_hours: 8)

      get user_path(alice)

      expect(response.body).to include("Group Leadership")
      expect(response.body).to include("<strong>0</strong> / 8 hours")
    end

    it "forbids participants from viewing other users" do
      sign_in create(:user)

      get user_path(alice)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PRD acceptance scenario" do
    let(:alice) { create(:user, email: "alice@example.com") }

    it "accumulates hours across two courses until the requirement completes" do
      sign_in create(:user, :admin)

      # 1. Admin creates the "Group Leadership" requirement (8 hours).
      post juleica_requirements_path, params: {
        juleica_requirement: { name: "Group Leadership", required_hours: 8 }
      }
      requirement = JuleicaRequirement.find_by!(name: "Group Leadership")

      # 2. Admin creates an organization and a course contributing 4 hours.
      post organizations_path, params: {
        organization: { name: "St. Martin's" }
      }
      organization = Organization.find_by!(name: "St. Martin's")

      post courses_path, params: {
        course: {
          name: "Youth Leadership Weekend",
          starts_at: "2026-10-10T18:00",
          ends_at: "2026-10-11T17:00",
          location: "Parish Hall",
          organization_id: organization.id,
          course_requirements_attributes: {
            "0" => { juleica_requirement_id: requirement.id, hours: "4" }
          }
        }
      }
      first_course = Course.find_by!(name: "Youth Leadership Weekend")

      # 3. Alice is registered for the course.
      post course_course_attendances_path(first_course), params: {
        course_attendance: { user_id: alice.id }
      }

      # 4. Alice's attendance is marked attended.
      patch course_course_attendance_path(first_course, CourseAttendance.sole),
            params: { course_attendance: { status: "attended" } }

      # 5. Progress shows 4 / 8, incomplete.
      get user_path(alice)
      expect(response.body).to include("<strong>4</strong> / 8 hours")
      expect(response.body).to include("In progress")
      expect(response.body).not_to include(">Complete<")

      # 6-7. A second course contributes another 4 hours.
      post courses_path, params: {
        course: {
          name: "Games & Group Work Weekend",
          starts_at: "2026-11-07T18:00",
          ends_at: "2026-11-08T17:00",
          location: "Community Center",
          organization_id: organization.id,
          course_requirements_attributes: {
            "0" => { juleica_requirement_id: requirement.id, hours: "4" }
          }
        }
      }
      second_course = Course.find_by!(name: "Games & Group Work Weekend")

      # 8. Alice attends the second course.
      post course_course_attendances_path(second_course), params: {
        course_attendance: { user_id: alice.id }
      }
      second_attendance = CourseAttendance.where(course: second_course).sole
      patch course_course_attendance_path(second_course, second_attendance),
            params: { course_attendance: { status: "attended" } }

      # 9. Progress now shows 8 / 8 and complete.
      get user_path(alice)
      aggregate_failures do
        expect(response.body).to include("<strong>8</strong> / 8 hours")
        expect(response.body).to include(">Complete</span>")
        expect(response.body).to include("Youth Leadership Weekend")
        expect(response.body).to include("Games &amp; Group Work Weekend")
      end
    end
  end

  describe "recommendations" do
    it "lists upcoming courses covering missing requirements on the progress page" do
      user = create(:user)
      sign_in user
      missing = create(:juleica_requirement, name: "Child Protection", required_hours: 4)
      helpful = create(:course, name: "Safeguarding Weekend", starts_at: 1.week.from_now)
      create(:course_requirement, course: helpful, juleica_requirement: missing, hours: 4)

      get user_path(user)

      expect(response.body).to include("Recommended Upcoming Courses")
      expect(response.body).to include("Safeguarding Weekend")
    end
  end
end
