require "rails_helper"

RSpec.describe "Programs" do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }

  def sign_in_organiser_for(target_organization)
    user = create(:user)
    create(:organization_membership, :organiser, user: user, organization: target_organization)
    sign_in user
    user
  end

  describe "GET /programs" do
    it "allows plain users to browse programs" do
      sign_in create(:user)
      program = create(:program, organization: organization)

      get programs_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(program.name)
      end
    end
  end

  describe "GET /programs/:id" do
    it "shows the program with its units" do
      sign_in create(:user)
      program = create(:program, organization: organization)
      unit = create(:unit, program: program)

      get program_path(program)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(program.name)
        expect(response.body).to include(unit.name)
      end
    end

    it "renders the new form for admins" do
      sign_in create(:user, :admin)

      get new_program_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the edit form for organisers" do
      sign_in_organiser_for(organization)
      program = create(:program, organization: organization)

      get edit_program_path(program)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(program.name)
      end
    end
  end

  describe "POST /programs" do
    it "lets an admin create a program" do
      sign_in create(:user, :admin)

      expect {
        post programs_path, params: {
          program: { name: "Summer Camp", kind: "freizeit", organization_id: organization.id }
        }
      }.to change(Program, :count).by(1)

      expect(Program.last.organization).to eq(organization)
    end

    it "lets an organiser create a program for their own organization" do
      sign_in_organiser_for(organization)

      expect {
        post programs_path, params: {
          program: { name: "Training", kind: "schooling", organization_id: organization.id }
        }
      }.to change(Program, :count).by(1)
    end

    it "clamps the organization to the organiser's own when tampering" do
      sign_in_organiser_for(organization)

      post programs_path, params: {
        program: { name: "Tampered", kind: "schooling", organization_id: other_organization.id }
      }

      aggregate_failures do
        expect(Program.last.organization).to eq(organization)
        expect(Program.last.organization).not_to eq(other_organization)
      end
    end

    it "lets an admin create a program with a new kind" do
      sign_in create(:user, :admin)

      expect {
        post programs_path, params: {
          program: { name: "Seminartag", kind: "seminar_day", organization_id: organization.id }
        }
      }.to change(Program, :count).by(1)

      aggregate_failures do
        expect(Program.last).to be_seminar_day
        expect(response).to redirect_to(program_path(Program.last))
        follow_redirect!
        expect(response.body).to include("Seminartag")
      end
    end

    it "rejects invalid submissions" do
      sign_in create(:user, :admin)

      post programs_path, params: { program: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "forbids plain users from creating programs" do
      sign_in create(:user)

      expect {
        post programs_path, params: { program: { name: "Nope", kind: "schooling", organization_id: organization.id } }
      }.not_to change(Program, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH /programs/:id" do
    it "updates a program of their own organization" do
      sign_in_organiser_for(organization)
      program = create(:program, organization: organization)

      patch program_path(program), params: { program: { name: "Renamed" } }

      aggregate_failures do
        expect(response).to redirect_to(program_path(program))
        expect(program.reload.name).to eq("Renamed")
      end
    end

    it "prevents organisers of another organization from editing" do
      sign_in_organiser_for(other_organization)
      program = create(:program, organization: organization)

      patch program_path(program), params: { program: { name: "Hijacked" } }

      expect(program.reload.name).not_to eq("Hijacked")
      expect(response).to redirect_to(root_path)
    end
  end

  describe "program attendance management" do
    let!(:program) { create(:program, organization: organization) }
    let!(:participant) { create(:user) }

    before { sign_in_organiser_for(organization) }

    it "registers a user and marks them attended" do
      expect {
        post program_program_attendances_path(program), params: { program_attendance: { user_id: participant.id } }
      }.to change(ProgramAttendance, :count).by(1)

      attendance = ProgramAttendance.sole
      expect(attendance.status).to eq("registered")

      patch program_program_attendance_path(program, attendance),
            params: { program_attendance: { status: "attended" } }

      expect(attendance.reload.status).to eq("attended")
      expect(response).to redirect_to(program_path(program))
    end

    it "refuses duplicate registrations" do
      create(:program_attendance, program: program, user: participant)

      expect {
        post program_program_attendances_path(program), params: { program_attendance: { user_id: participant.id } }
      }.not_to change(ProgramAttendance, :count)

      expect(response).to redirect_to(program_path(program))
      follow_redirect!
      expect(flash[:alert]).to be_present
    end

    it "shows attendees on the program page for the organizing church" do
      create(:program_attendance, :attended, program: program, user: participant)

      get program_path(program)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(participant.email)
        expect(response.body).to include(I18n.t("activerecord.enums.program_attendance.status.attended"))
      end
    end

    it "removes an attendance record" do
      attendance = create(:program_attendance, program: program, user: participant)

      expect {
        delete program_program_attendance_path(program, attendance)
      }.to change(ProgramAttendance, :count).by(-1)

      expect(response).to redirect_to(program_path(program))
    end

    it "hides attendees from organisers of another organization" do
      other_participant = create(:user, email: "otherchurch@example.com")
      create(:program_attendance, :attended, program: program, user: other_participant)
      sign_in_organiser_for(other_organization)

      get program_path(program)

      aggregate_failures do
        expect(response.body).not_to include(I18n.t("programs.show.attendees"))
        expect(response.body).not_to include("otherchurch@example.com")
      end
    end

    it "forbids plain users from changing attendance" do
      sign_in create(:user)
      attendance = create(:program_attendance, program: program)

      patch program_program_attendance_path(program, attendance),
            params: { program_attendance: { status: "attended" } }

      expect(response).to redirect_to(root_path)
      expect(attendance.reload.status).not_to eq("attended")
    end
  end

  describe "DELETE /programs/:id" do
    it "deletes an empty program" do
      sign_in_organiser_for(organization)
      program = create(:program, organization: organization)

      expect {
        delete program_path(program)
      }.to change(Program, :count).by(-1)

      expect(response).to redirect_to(programs_path)
    end

    it "protects programs with units from deletion" do
      sign_in_organiser_for(organization)
      program = create(:program, organization: organization)
      create(:unit, program: program)

      delete program_path(program)

      expect(Program.exists?(program.id)).to be(true)
      follow_redirect!
      expect(flash[:alert]).to be_present
    end

    it "prevents organisers of another organization from deleting" do
      sign_in_organiser_for(other_organization)
      program = create(:program, organization: organization)

      expect {
        delete program_path(program)
      }.not_to change(Program, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
