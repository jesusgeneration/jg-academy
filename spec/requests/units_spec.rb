require "rails_helper"

RSpec.describe "Units" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:program) { create(:program, organization: organization) }
  let(:other_program) { create(:program, organization: other_organization) }

  def sign_in_organiser_for(target_organization)
    user = create(:user)
    create(:organization_membership, :organiser, user: user, organization: target_organization)
    sign_in user
    user
  end

  describe "GET /units" do
    it "allows plain users to browse upcoming units" do
      sign_in create(:user)
      unit = create(:unit, program: program)

      get units_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unit.name)
    end

    it "supports the past tab" do
      sign_in create(:user)
      past_unit = create(:unit, :past, program: program)

      get units_path, params: { tab: "past" }

      expect(response.body).to include(past_unit.name)
    end
  end

  describe "GET /units/:id" do
    it "renders the unit page for plain users" do
      sign_in create(:user)
      unit = create(:unit, program: program)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(unit.name)
      end
    end
  end

  describe "POST /units" do
    let(:admin) { create(:user, :admin) }

    before { sign_in admin }

    it "creates a unit" do
      post units_path, params: {
        unit: {
          name: "Youth Leadership Unit 2026",
          description: "A leadership unit.",
          location: "Parish Hall",
          starts_at: "2026-10-10T18:00",
          ends_at: "2026-10-11T17:00",
          program_id: program.id
        }
      }

      unit = Unit.find_by!(name: "Youth Leadership Unit 2026")
      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.program).to eq(program)
      end
    end

    it "renders the new form" do
      get new_unit_path

      expect(response).to have_http_status(:ok)
    end

    it "rejects invalid submissions" do
      post units_path, params: { unit: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "organizer-scoped management" do
    let!(:unit) { create(:unit, program: program) }

    it "renders the new form for organisers" do
      sign_in_organiser_for(organization)

      get new_unit_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the edit form for the organizing church" do
      sign_in_organiser_for(organization)

      get edit_unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(unit.name)
      end
    end

    it "updates a unit of their own organization" do
      sign_in_organiser_for(organization)

      patch unit_path(unit), params: {
        unit: {
          name: "Renamed Unit",
          starts_at: "2026-10-10T18:00",
          ends_at: "2026-10-11T17:00",
          program_id: program.id
        }
      }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.reload.name).to eq("Renamed Unit")
      end
    end

    it "deletes a unit of their own organization" do
      sign_in_organiser_for(organization)

      expect {
        delete unit_path(unit)
      }.to change(Unit, :count).by(-1)

      expect(response).to redirect_to(program_path(program))
    end

    it "lets an organiser create a unit for their own organization" do
      sign_in_organiser_for(organization)

      expect {
        post units_path, params: { unit: unit_params_for(program.id) }
      }.to change(Unit, :count).by(1)

      expect(Unit.last.program).to eq(program)
    end

    it "clamps the program to the organiser's own when tampering" do
      sign_in_organiser_for(organization)

      post units_path, params: { unit: unit_params_for(other_program.id) }

      aggregate_failures do
        expect(Unit.last.program).to eq(program)
        expect(Unit.last.program).not_to eq(other_program)
      end
    end

    it "clamps the program on update when tampering" do
      sign_in_organiser_for(organization)

      patch unit_path(unit), params: { unit: { program_id: other_program.id } }

      expect(unit.reload.program).to eq(program)
    end

    it "prevents organisers of another organization from editing its units" do
      sign_in_organiser_for(other_organization)

      patch unit_path(unit), params: { unit: { name: "Hijacked" } }

      expect(unit.reload.name).not_to eq("Hijacked")
      expect(response).to redirect_to(root_path)
    end

    it "prevents organisers of another organization from deleting its units" do
      sign_in_organiser_for(other_organization)

      expect {
        delete unit_path(unit)
      }.not_to change(Unit, :count)

      expect(response).to redirect_to(root_path)
    end

    private

    def unit_params_for(tampered_program_id)
      {
        name: "Organiser Unit",
        starts_at: "2026-10-10T18:00",
        ends_at: "2026-10-11T17:00",
        program_id: tampered_program_id
      }
    end
  end

  describe "attendance management" do
    let!(:unit) { create(:unit, program: program) }
    let!(:participant) { create(:user) }

    before { sign_in_organiser_for(organization) }

    it "registers a user and marks them attended" do
      expect {
        post unit_unit_attendances_path(unit), params: { unit_attendance: { user_id: participant.id } }
      }.to change(UnitAttendance, :count).by(1)

      attendance = UnitAttendance.sole
      expect(attendance.status).to eq("registered")

      patch unit_unit_attendance_path(unit, attendance),
            params: { unit_attendance: { status: "attended" } }

      expect(attendance.reload.status).to eq("attended")
      expect(response).to redirect_to(unit_path(unit))
    end

    it "refuses duplicate registrations" do
      create(:unit_attendance, unit: unit, user: participant)

      expect {
        post unit_unit_attendances_path(unit), params: { unit_attendance: { user_id: participant.id } }
      }.not_to change(UnitAttendance, :count)

      expect(response).to redirect_to(unit_path(unit))
      follow_redirect!
      expect(flash[:alert]).to be_present
    end

    it "shows attendees on the unit page for the organizing church" do
      create(:unit_attendance, :attended, unit: unit, user: participant)

      get unit_path(unit)

      expect(response.body).to include(participant.email)
      expect(response.body).to include("Attended")
    end

    it "removes an attendance record" do
      attendance = create(:unit_attendance, unit: unit, user: participant)

      expect {
        delete unit_unit_attendance_path(unit, attendance)
      }.to change(UnitAttendance, :count).by(-1)

      expect(response).to redirect_to(unit_path(unit))
    end

    it "hides attendees from organisers of another organization" do
      other_participant = create(:user, email: "otherchurch@example.com")
      create(:unit_attendance, :attended, unit: unit, user: other_participant)
      sign_in_organiser_for(other_organization)

      get unit_path(unit)

      aggregate_failures do
        expect(response.body).not_to include("Attendees")
        expect(response.body).not_to include("otherchurch@example.com")
      end
    end
  end

  describe "coverage management" do
    let!(:unit) { create(:unit, program: program) }
    let!(:level) { create(:content, :level, title: "Level 1") }
    let!(:detail) { create(:content, :detail, title: "Detail 1.1.1") }

    before { sign_in_organiser_for(organization) }

    it "adds coverage to a unit of their own organization" do
      expect {
        post unit_unit_coverages_path(unit), params: { unit_coverage: { content_id: level.id } }
      }.to change(UnitCoverage, :count).by(1)

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.reload.covers?(level)).to be(true)
      end
    end

    it "refuses duplicate coverage" do
      create(:unit_coverage, unit: unit, content: level)

      expect {
        post unit_unit_coverages_path(unit), params: { unit_coverage: { content_id: level.id } }
      }.not_to change(UnitCoverage, :count)

      expect(response).to redirect_to(unit_path(unit))
      follow_redirect!
      expect(flash[:alert]).to be_present
    end

    it "removes coverage from a unit of their own organization" do
      coverage = create(:unit_coverage, unit: unit, content: detail)

      expect {
        delete unit_unit_coverage_path(unit, coverage)
      }.to change(UnitCoverage, :count).by(-1)

      expect(response).to redirect_to(unit_path(unit))
    end

    it "shows the coverage editor on the unit page for the organizing church" do
      section = create(:content, :section, parent: level, title: "Level 1.1")
      create(:content, :detail, parent: section, title: "Detail 1.1.9")
      create(:unit_coverage, unit: unit, content: level)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Manage coverage")
        expect(response.body).to include("Level 1")
        expect(response.body).to include("Level 1.1")
        expect(response.body).to include("Detail 1.1.9")
        expect(response.body).to include("covered via Level 1")
        expect(response.body).to include("collapse")
        expect(response.body).to include("checked")
        # Covered level keeps Remove; its section and detail get no button.
        # Only the 3 uncovered items of the other tree keep Add.
        expect(response.body.scan(">Remove</button>").size).to eq(1)
        expect(response.body.scan(">Add</button>").size).to eq(3)
      end
    end

    it "hides Add buttons on details of a covered section" do
      section = create(:content, :section, parent: level, title: "Level 1.1")
      create(:content, :detail, parent: section, title: "Detail 1.1.9")
      create(:unit_coverage, unit: unit, content: section)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("covered via Level 1.1")
        # Level, section keep their buttons; the detail gets none.
        expect(response.body.scan(">Remove</button>").size).to eq(1)
        expect(response.body.scan(">Add</button>").size).to eq(4)
      end
    end

    it "hides the coverage editor from organisers of another organization" do
      sign_in_organiser_for(other_organization)

      get unit_path(unit)

      expect(response.body).not_to include("Manage coverage")
    end

    it "prevents organisers of another organization from adding coverage" do
      sign_in_organiser_for(other_organization)

      expect {
        post unit_unit_coverages_path(unit), params: { unit_coverage: { content_id: level.id } }
      }.not_to change(UnitCoverage, :count)

      expect(response).to redirect_to(root_path)
    end

    it "forbids plain users from adding coverage" do
      sign_in create(:user)

      expect {
        post unit_unit_coverages_path(unit), params: { unit_coverage: { content_id: level.id } }
      }.not_to change(UnitCoverage, :count)

      expect(response).to redirect_to(root_path)
    end

    it "hides the coverage editor from plain users" do
      sign_in create(:user)

      get unit_path(unit)

      expect(response.body).not_to include("Manage coverage")
    end
  end

  describe "attendee visibility" do
    let!(:unit) { create(:unit, program: program) }
    let!(:attendee) { create(:user, email: "attendee@example.com") }

    before { create(:unit_attendance, :attended, unit: unit, user: attendee) }

    it "hides attendees from plain users on the index page" do
      sign_in create(:user)

      get units_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Attendees")
        expect(response.body).not_to include("attendee@example.com")
        expect(response.body).to include(unit.name)
      end
    end

    it "hides attendees from plain users on the detail page" do
      sign_in create(:user)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Attendees")
        expect(response.body).not_to include("attendee@example.com")
        expect(response.body).to include("Covers")
        expect(response.body).to include(unit.starts_at.strftime("%d %b %Y"))
      end
    end

    it "shows attendees to organisers on the detail page" do
      sign_in_organiser_for(organization)

      get unit_path(unit)

      aggregate_failures do
        expect(response.body).to include("Attendees")
        expect(response.body).to include("attendee@example.com")
      end
    end

    it "shows attendees to admins on the index page" do
      sign_in create(:user, :admin)

      get units_path

      aggregate_failures do
        expect(response.body).to include("Attendees")
        expect(response.body).to include(unit.name)
      end
    end
  end

  describe "authorization" do
    it "forbids plain users from creating units" do
      sign_in create(:user)

      expect {
        post units_path, params: { unit: { name: "Nope" } }
      }.not_to change(Unit, :count)

      expect(response).to redirect_to(root_path)
    end

    it "forbids plain users from changing attendance" do
      sign_in create(:user)
      unit = create(:unit)
      attendance = create(:unit_attendance, unit: unit)

      patch unit_unit_attendance_path(unit, attendance), params: { unit_attendance: { status: "attended" } }

      expect(attendance.reload.status).not_to eq("attended")
    end
  end
end
