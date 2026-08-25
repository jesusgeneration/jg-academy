require "rails_helper"

RSpec.describe "Courses" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  def sign_in_organiser_for(target_organization)
    user = create(:user)
    create(:organization_membership, :organiser, user: user, organization: target_organization)
    sign_in user
    user
  end

  describe "GET /courses" do
    it "allows plain users to browse upcoming courses" do
      sign_in create(:user)
      course = create(:course, organization: organization)

      get courses_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(course.name)
    end

    it "supports the past tab" do
      sign_in create(:user)
      past_course = create(:course, :past, organization: organization)

      get courses_path, params: { tab: "past" }

      expect(response.body).to include(past_course.name)
    end
  end

  describe "POST /courses" do
    let(:admin) { create(:user, :admin) }
    let(:requirement) { create(:juleica_requirement, name: "Group Leadership") }

    before { sign_in admin }

    it "creates a course with nested course requirements" do
      post courses_path, params: {
        course: {
          name: "Youth Leadership Weekend 2026",
          description: "A leadership weekend.",
          location: "Parish Hall",
          starts_at: "2026-10-10T18:00",
          ends_at: "2026-10-11T17:00",
          organization_id: organization.id,
          course_requirements_attributes: {
            "0" => { juleica_requirement_id: requirement.id, hours: "4" }
          }
        }
      }

      course = Course.find_by!(name: "Youth Leadership Weekend 2026")
      aggregate_failures do
        expect(response).to redirect_to(course_path(course))
        expect(course.course_requirements.sole.hours).to eq(4)
        expect(course.course_requirements.sole.juleica_requirement).to eq(requirement)
      end
    end

    it "rejects invalid submissions" do
      post courses_path, params: { course: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "organizer-scoped management" do
    let!(:course) { create(:course, organization: organization) }

    it "renders the new form for organisers" do
      sign_in_organiser_for(organization)

      get new_course_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the edit form for the organizing church" do
      sign_in_organiser_for(organization)

      get edit_course_path(course)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(course.name)
      end
    end

    it "updates a course of their own organization" do
      sign_in_organiser_for(organization)

      patch course_path(course), params: {
        course: {
          name: "Renamed Weekend",
          starts_at: "2026-10-10T18:00",
          ends_at: "2026-10-11T17:00",
          organization_id: organization.id
        }
      }

      aggregate_failures do
        expect(response).to redirect_to(course_path(course))
        expect(course.reload.name).to eq("Renamed Weekend")
      end
    end

    it "deletes a course of their own organization" do
      sign_in_organiser_for(organization)

      expect {
        delete course_path(course)
      }.to change(Course, :count).by(-1)

      expect(response).to redirect_to(courses_path)
    end

    it "lets an organiser create a course for their own organization" do
      sign_in_organiser_for(organization)

      expect {
        post courses_path, params: { course: course_params_for(organization.id) }
      }.to change(Course, :count).by(1)

      expect(Course.last.organization).to eq(organization)
    end

    it "clamps the organization to the organiser's own when tampering" do
      sign_in_organiser_for(organization)

      post courses_path, params: { course: course_params_for(other_organization.id) }

      aggregate_failures do
        expect(Course.last.organization).to eq(organization)
        expect(Course.last.organization).not_to eq(other_organization)
      end
    end

    it "prevents organisers of another organization from editing its courses" do
      sign_in_organiser_for(other_organization)

      patch course_path(course), params: { course: { name: "Hijacked" } }

      expect(course.reload.name).not_to eq("Hijacked")
      expect(response).to redirect_to(root_path)
    end

    it "prevents organisers of another organization from deleting its courses" do
      sign_in_organiser_for(other_organization)

      expect {
        delete course_path(course)
      }.not_to change(Course, :count)

      expect(response).to redirect_to(root_path)
    end

    private

    def course_params_for(tampered_organization_id)
      {
        name: "Organiser Course",
        starts_at: "2026-10-10T18:00",
        ends_at: "2026-10-11T17:00",
        organization_id: tampered_organization_id
      }
    end
  end

  describe "attendance management" do
    let!(:course) { create(:course, organization: organization) }
    let!(:participant) { create(:user) }

    before { sign_in_organiser_for(organization) }

    it "registers a user and marks them attended" do
      expect {
        post course_course_attendances_path(course), params: { course_attendance: { user_id: participant.id } }
      }.to change(CourseAttendance, :count).by(1)

      attendance = CourseAttendance.sole
      expect(attendance.status).to eq("registered")

      patch course_course_attendance_path(course, attendance),
            params: { course_attendance: { status: "attended" } }

      expect(attendance.reload.status).to eq("attended")
      expect(response).to redirect_to(course_path(course))
    end

    it "refuses duplicate registrations" do
      create(:course_attendance, course: course, user: participant)

      expect {
        post course_course_attendances_path(course), params: { course_attendance: { user_id: participant.id } }
      }.not_to change(CourseAttendance, :count)

      expect(response).to redirect_to(course_path(course))
      follow_redirect!
      expect(flash[:alert]).to be_present
    end

    it "shows attendees on the course page for the organizing church" do
      create(:course_attendance, :attended, course: course, user: participant)

      get course_path(course)

      expect(response.body).to include(participant.email)
      expect(response.body).to include("Attended")
    end

    it "removes an attendance record" do
      attendance = create(:course_attendance, course: course, user: participant)

      expect {
        delete course_course_attendance_path(course, attendance)
      }.to change(CourseAttendance, :count).by(-1)

      expect(response).to redirect_to(course_path(course))
    end

    it "hides attendees from organisers of another organization" do
      other_participant = create(:user, email: "otherchurch@example.com")
      create(:course_attendance, :attended, course: course, user: other_participant)
      sign_in_organiser_for(other_organization)

      get course_path(course)

      aggregate_failures do
        expect(response.body).not_to include("Attendees")
        expect(response.body).not_to include("otherchurch@example.com")
      end
    end
  end

  describe "attendee visibility" do
    let!(:course) { create(:course, organization: organization) }
    let!(:attendee) { create(:user, email: "attendee@example.com") }

    before { create(:course_attendance, :attended, course: course, user: attendee) }

    it "hides attendees from plain users on the index page" do
      sign_in create(:user)

      get courses_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Attendees")
        expect(response.body).not_to include("attendee@example.com")
        expect(response.body).to include(course.name)
      end
    end

    it "hides attendees from plain users on the detail page" do
      sign_in create(:user)

      get course_path(course)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Attendees")
        expect(response.body).not_to include("attendee@example.com")
        expect(response.body).to include("Counts Toward")
        expect(response.body).to include(course.starts_at.strftime("%d %b %Y"))
      end
    end

    it "shows attendees to organisers on the detail page" do
      sign_in_organiser_for(organization)

      get course_path(course)

      aggregate_failures do
        expect(response.body).to include("Attendees")
        expect(response.body).to include("attendee@example.com")
      end
    end

    it "shows attendees to admins on the index page" do
      sign_in create(:user, :admin)

      get courses_path

      aggregate_failures do
        expect(response.body).to include("Attendees")
        expect(response.body).to include(course.name)
      end
    end
  end

  describe "authorization" do
    it "forbids plain users from creating courses" do
      sign_in create(:user)

      expect {
        post courses_path, params: { course: { name: "Nope" } }
      }.not_to change(Course, :count)

      expect(response).to redirect_to(root_path)
    end

    it "forbids plain users from changing attendance" do
      sign_in create(:user)
      course = create(:course)
      attendance = create(:course_attendance, course: course)

      patch course_course_attendance_path(course, attendance), params: { course_attendance: { status: "attended" } }

      expect(attendance.reload.status).not_to eq("attended")
    end
  end
end
