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

    it "supports the planned tab for units without dates" do
      sign_in create(:user)
      planned_unit = create(:unit, program: program, name: "Planned Vision", starts_at: nil, ends_at: nil)
      scheduled_unit = create(:unit, program: program)

      get units_path, params: { tab: "planned" }

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.index.tabs.planned"))
        expect(response.body).to include(planned_unit.name)
        expect(response.body).not_to include(scheduled_unit.name)
      end
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
          start_date: "2026-10-10",
          start_time: "18:00",
          duration_minutes: "60",
          program_id: program.id
        }
      }

      unit = Unit.find_by!(name: "Youth Leadership Unit 2026")
      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.program).to eq(program)
        expect(unit.starts_at).to eq(Time.zone.local(2026, 10, 10, 18, 0))
        expect(unit.ends_at).to eq(Time.zone.local(2026, 10, 10, 19, 0))
      end
    end

    it "renders the new form" do
      get new_unit_path

      expect(response).to have_http_status(:ok)
    end

    it "shows the coverage tree on the new form" do
      level = create(:content, :level, title: "Level Tree")

      get new_unit_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.form.manage_coverage"))
        expect(response.body).to include("Level Tree")
        expect(response.body).to include("coverage_content_ids[]")
      end
    end

    it "creates coverages for selected contents" do
      level = create(:content, :level)
      detail = create(:content, :detail)

      expect {
        post units_path, params: {
          unit: {
            name: "Covered Unit",
            start_date: "2026-10-10",
            start_time: "18:00",
            duration_minutes: "60",
            program_id: program.id
          },
          coverage_content_ids: [ level.id.to_s, detail.id.to_s ]
        }
      }.to change(UnitCoverage, :count).by(2)

      unit = Unit.find_by!(name: "Covered Unit")
      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.covered_contents).to contain_exactly(level, detail)
      end
    end

    it "ignores invalid coverage ids" do
      expect {
        post units_path, params: {
          unit: {
            name: "Plain Unit",
            start_date: "2026-10-10",
            start_time: "18:00",
            program_id: program.id
          },
          coverage_content_ids: [ "999999" ]
        }
      }.to change(UnitCoverage, :count).by(0)

      expect(response).to redirect_to(unit_path(Unit.find_by!(name: "Plain Unit")))
    end

    it "re-renders the coverage tree on invalid submissions" do
      level = create(:content, :level, title: "Level Rerender")

      post units_path, params: {
        unit: { name: "", program_id: program.id },
        coverage_content_ids: [ level.id.to_s ]
      }

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Level Rerender")
        expect(response.body).to include("checked=\"checked\"")
      end
    end

    it "renders the new form without a preselected program" do
      get new_unit_path

      program_select = response.body[/<select[^>]*name="unit\[program_id\]"[^>]*>.*?<\/select>/m]

      aggregate_failures do
        expect(program_select).to include(I18n.t("units.form.select_program"))
        expect(program_select.scan(/selected="selected"/).size).to eq(0)
      end
    end

    it "offers split date and time fields without free time entry" do
      get new_unit_path

      time_select = response.body[/<select[^>]*name="unit\[start_time\]"[^>]*>.*?<\/select>/m]

      aggregate_failures do
        expect(response.body).not_to include('type="datetime-local"')
        expect(response.body).not_to include("unit[end_date]")
        expect(response.body).to include(I18n.t("units.form.time"))
        expect(response.body).to include("sm:col-span-2")
        expect(response.body).to include("fieldset min-w-0")
        expect(response.body).to include("grid-cols-[1fr_auto]")
        expect(time_select).to include("max-w-40")
        expect(time_select.scan(/<option value="(\d\d:\d\d)"/).flatten.size).to eq(68)
        expect(time_select).to include('<option value="07:00">07:00</option>')
        expect(time_select).to include('<option value="23:45">23:45</option>')
      end
    end

    it "rounds legacy times to the nearest quarter hour on the edit form" do
      sign_in create(:user, :admin)
      unit = create(:unit, program: program,
        starts_at: Time.zone.local(2026, 10, 10, 18, 10),
        ends_at: Time.zone.local(2026, 10, 10, 20, 0))

      get edit_unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('<option selected="selected" value="18:15">18:15</option>')
      end
    end

    it "keeps legacy hours outside 7-23 selectable on the edit form" do
      sign_in create(:user, :admin)
      unit = create(:unit, program: program,
        starts_at: Time.zone.local(2026, 10, 10, 6, 15),
        ends_at: Time.zone.local(2026, 10, 10, 20, 0))

      get edit_unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('<option selected="selected" value="06:15">06:15</option>')
      end
    end

    it "creates a unit from start date, time and duration" do
      post units_path, params: {
        unit: {
          name: "Split Unit",
          start_date: "2026-10-10",
          start_time: "18:15",
          duration_minutes: "75",
          program_id: program.id
        }
      }

      unit = Unit.find_by!(name: "Split Unit")
      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.starts_at).to eq(Time.zone.local(2026, 10, 10, 18, 15))
        expect(unit.ends_at).to eq(Time.zone.local(2026, 10, 10, 19, 30))
      end
    end

    it "creates an unscheduled unit without dates" do
      post units_path, params: {
        unit: {
          name: "Planned Unit",
          program_id: program.id
        }
      }

      unit = Unit.find_by!(name: "Planned Unit")
      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.starts_at).to be_nil
        expect(unit.ends_at).to be_nil
      end
    end

    it "flags unscheduled units on the unit page" do
      unit = create(:unit, program: program, starts_at: nil, ends_at: nil)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.show.status.unscheduled"))
      end
    end

    it "creates a unit from start plus duration" do
      post units_path, params: {
        unit: {
          name: "Evening Unit",
          start_date: "2026-10-10",
          start_time: "18:00",
          duration_minutes: "75",
          program_id: program.id
        }
      }

      unit = Unit.find_by!(name: "Evening Unit")
      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.ends_at).to eq(Time.zone.local(2026, 10, 10, 19, 15))
      end
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
          start_date: "2026-10-10",
          start_time: "18:00",
          duration_minutes: "60",
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

    it "updates a unit from duration" do
      sign_in_organiser_for(organization)

      patch unit_path(unit), params: {
        unit: {
          start_date: "2026-10-10",
          start_time: "18:00",
          duration_minutes: "60",
          program_id: program.id
        }
      }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.reload.ends_at).to eq(Time.zone.local(2026, 10, 10, 19, 0))
      end
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
        start_date: "2026-10-10",
        start_time: "18:00",
        duration_minutes: "60",
        program_id: tampered_program_id
      }
    end
  end

  describe "attendance management" do
    let!(:unit) { create(:unit, program: program, instructor: create(:user, :admin)) }
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
      expect(response.body).to include(I18n.t("activerecord.enums.unit_attendance.status.attended"))
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
        expect(response.body).not_to include(I18n.t("units.show.attendees"))
        expect(response.body).not_to include("otherchurch@example.com")
      end
    end
  end

  describe "instructor management" do
    let!(:unit) { create(:unit, program: program) }

    def eligible_organiser(email)
      user = create(:user, email: email)
      create(:organization_membership, :organiser, user: user, organization: organization)
      user
    end

    it "offers only eligible instructors on the new form" do
      sign_in_organiser_for(organization)
      instructor = eligible_organiser("instructor@example.com")
      admin = create(:user, :admin, email: "admin@example.com")
      plain = create(:user, email: "plain@example.com")

      get new_unit_path

      select = response.body[/<select[^>]*name="unit\[instructor_id\]"[^>]*>.*?<\/select>/m]
      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.form.instructor"))
        expect(select).to include(I18n.t("units.form.select_instructor"))
        expect(select).to include(instructor.email)
        expect(select).to include(admin.email)
        expect(select).not_to include(plain.email)
      end
    end

    it "creates a unit with an instructor" do
      instructor = eligible_organiser("instructor@example.com")
      sign_in_organiser_for(organization)

      post units_path, params: {
        unit: { name: "Instructed Unit", program_id: program.id, instructor_id: instructor.id }
      }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(Unit.find_by!(name: "Instructed Unit")))
        expect(Unit.find_by!(name: "Instructed Unit").instructor).to eq(instructor)
      end
    end

    it "rejects an ineligible instructor" do
      sign_in_organiser_for(organization)

      expect {
        post units_path, params: {
          unit: { name: "Bad Instructor Unit", program_id: program.id, instructor_id: create(:user).id }
        }
      }.not_to change(Unit, :count)

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t("units.form.errors_prevented", count: 1))
      end
    end

    it "shows the instructor on the unit page" do
      instructor = eligible_organiser("instructor@example.com")
      unit.update!(instructor: instructor)
      sign_in instructor

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.show.instructor"))
        expect(response.body).to include(instructor.email)
      end
    end

    it "shows a placeholder without an instructor" do
      sign_in_organiser_for(organization)

      get unit_path(unit)

      expect(response.body).to include(I18n.t("units.show.no_instructor"))
    end

    it "blocks attended without an instructor but allows it with one" do
      sign_in_organiser_for(organization)
      attendance = create(:unit_attendance, unit: unit, user: create(:user))

      patch unit_unit_attendance_path(unit, attendance),
            params: { unit_attendance: { status: "attended" } }
      expect(attendance.reload.status).to eq("registered")

      unit.update!(instructor: create(:user, :admin))
      patch unit_unit_attendance_path(unit, attendance),
            params: { unit_attendance: { status: "attended" } }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(attendance.reload.status).to eq("attended")
      end
    end

    it "lets a fellow organiser still edit other fields after attended" do
      instructor = eligible_organiser("instructor@example.com")
      unit.update!(instructor: instructor)
      create(:unit_attendance, :attended, unit: unit, user: create(:user))
      sign_in_organiser_for(organization)

      patch unit_path(unit), params: { unit: { name: "Renamed After Attended" } }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.reload.name).to eq("Renamed After Attended")
      end
    end

    it "prevents a fellow organiser from changing the instructor after attended" do
      instructor = eligible_organiser("instructor@example.com")
      unit.update!(instructor: instructor)
      create(:unit_attendance, :attended, unit: unit, user: create(:user))
      replacement = eligible_organiser("replacement@example.com")
      sign_in replacement

      patch unit_path(unit), params: { unit: { instructor_id: replacement.id } }

      aggregate_failures do
        expect(response).to redirect_to(root_path)
        expect(unit.reload.instructor).to eq(instructor)
      end
    end

    it "lets the instructor change the instructor after attended" do
      instructor = eligible_organiser("instructor@example.com")
      unit.update!(instructor: instructor)
      create(:unit_attendance, :attended, unit: unit, user: create(:user))
      replacement = eligible_organiser("replacement@example.com")
      sign_in instructor

      patch unit_path(unit), params: { unit: { instructor_id: replacement.id } }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.reload.instructor).to eq(replacement)
      end
    end

    it "lets an admin change the instructor after attended" do
      instructor = eligible_organiser("instructor@example.com")
      unit.update!(instructor: instructor)
      create(:unit_attendance, :attended, unit: unit, user: create(:user))
      replacement = create(:user, :admin)
      sign_in replacement

      patch unit_path(unit), params: { unit: { instructor_id: replacement.id } }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unit))
        expect(unit.reload.instructor).to eq(replacement)
      end
    end
  end

  describe "attendance inheritance" do
    let!(:unit) { create(:unit, program: program) }

    before { sign_in_organiser_for(organization) }

    it "copies program participants with attended mapped to registered" do
      newcomer = create(:user)
      cancel_user = create(:user)
      create(:program_attendance, :attended, program: program, user: newcomer)
      create(:program_attendance, :cancelled, program: program, user: cancel_user)

      expect {
        post inherit_attendances_unit_path(unit)
      }.to change(UnitAttendance, :count).by(2)

      aggregate_failures do
        expect(UnitAttendance.find_by!(unit: unit, user: newcomer).status).to eq("registered")
        expect(UnitAttendance.find_by!(unit: unit, user: cancel_user).status).to eq("cancelled")
        expect(response).to redirect_to(unit_path(unit, anchor: "attendees"))
        follow_redirect!
        expect(response.body).to include(I18n.t("units.show.attendees"))
      end
    end

    it "keeps existing unit entries and only adds missing users" do
      keeper = create(:user)
      create(:unit_attendance, unit: unit, user: keeper, status: :cancelled)
      create(:program_attendance, program: program, user: keeper, status: :cancelled)
      newcomer = create(:user)
      create(:program_attendance, program: program, user: newcomer)

      expect {
        post inherit_attendances_unit_path(unit)
      }.to change(UnitAttendance, :count).by(1)

      aggregate_failures do
        expect(UnitAttendance.find_by!(unit: unit, user: keeper).status).to eq("cancelled")
        expect(UnitAttendance.find_by!(unit: unit, user: newcomer).status).to eq("registered")
      end
    end

    it "resolves conflicts only for explicitly imported users" do
      imported = create(:user)
      kept = create(:user)
      create(:program_attendance, :attended, program: program, user: imported)
      create(:unit_attendance, unit: unit, user: imported, status: :cancelled)
      create(:program_attendance, :attended, program: program, user: kept)
      create(:unit_attendance, unit: unit, user: kept, status: :no_show)

      expect {
        post inherit_attendances_unit_path(unit), params: { import_user_ids: [ imported.id ] }
      }.not_to change(UnitAttendance, :count)

      aggregate_failures do
        expect(UnitAttendance.find_by!(unit: unit, user: imported).status).to eq("registered")
        expect(UnitAttendance.find_by!(unit: unit, user: kept).status).to eq("no_show")
      end
    end

    it "links to the inherit preview page from the unit page" do
      conflict_user = create(:user)
      create(:program_attendance, :attended, program: program, user: conflict_user)
      create(:unit_attendance, unit: unit, user: conflict_user, status: :cancelled)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.show.inherit_button"))
        expect(response.body).to include(inherit_attendances_unit_path(unit))
      end
    end

    it "renders the inherit preview with conflict choices" do
      conflict_user = create(:user)
      create(:program_attendance, :attended, program: program, user: conflict_user)
      create(:unit_attendance, unit: unit, user: conflict_user, status: :cancelled)
      newcomer = create(:user)
      create(:program_attendance, program: program, user: newcomer)

      get inherit_attendances_unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.show.inherit_title"))
        expect(response.body).to include(conflict_user.email)
        expect(response.body).to include(I18n.t("units.show.inherit_apply"))
        expect(response.body).to include(I18n.t("units.show.inherit_back"))
      end
    end

    it "forbids plain users from viewing the inherit preview" do
      sign_in create(:user)

      get inherit_attendances_unit_path(unit)

      expect(response).to redirect_to(root_path)
    end

    it "forbids plain users from inheriting" do
      sign_in create(:user)
      newcomer = create(:user)
      create(:program_attendance, program: program, user: newcomer)

      expect {
        post inherit_attendances_unit_path(unit)
      }.not_to change(UnitAttendance, :count)

      expect(response).to redirect_to(root_path)
    end

    it "blocks attended on unscheduled units but allows registered" do
      unscheduled = create(:unit, program: program, starts_at: nil, ends_at: nil)
      attendance = create(:unit_attendance, unit: unscheduled, user: create(:user))

      patch unit_unit_attendance_path(unscheduled, attendance),
            params: { unit_attendance: { status: "attended" } }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(unscheduled))
        follow_redirect!
        expect(flash[:alert]).to be_present
        expect(attendance.reload.status).to eq("registered")
      end
    end

    it "allows attended with only a start time" do
      start_only = create(:unit, program: program, starts_at: 2.weeks.from_now, ends_at: nil,
        instructor: create(:user, :admin))
      attendance = create(:unit_attendance, unit: start_only, user: create(:user))

      patch unit_unit_attendance_path(start_only, attendance),
            params: { unit_attendance: { status: "attended" } }

      aggregate_failures do
        expect(response).to redirect_to(unit_path(start_only))
        expect(attendance.reload.status).to eq("attended")
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
        expect(response.body).to include(I18n.t("units.show.manage_coverage"))
        expect(response.body).to include("Level 1")
        expect(response.body).to include("Level 1.1")
        expect(response.body).to include("Detail 1.1.9")
        expect(response.body).to include(I18n.t("units.show.covered_via", title: "Level 1"))
        expect(response.body).to include("collapse")
        expect(response.body).to include("checked")
        # Covered level keeps Remove; its section and detail get no button.
        # Only the 3 uncovered items of the other tree keep Add.
        expect(response.body.scan(">#{(I18n.t("helpers.coverage.remove"))}</button>").size).to eq(1)
        expect(response.body.scan(">#{(I18n.t("helpers.coverage.add"))}</button>").size).to eq(3)
      end
    end

    it "hides Add buttons on details of a covered section" do
      section = create(:content, :section, parent: level, title: "Level 1.1")
      create(:content, :detail, parent: section, title: "Detail 1.1.9")
      create(:unit_coverage, unit: unit, content: section)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("units.show.covered_via", title: "Level 1.1"))
        # Level, section keep their buttons; the detail gets none.
        expect(response.body.scan(">#{(I18n.t("helpers.coverage.remove"))}</button>").size).to eq(1)
        expect(response.body.scan(">#{(I18n.t("helpers.coverage.add"))}</button>").size).to eq(4)
      end
    end

    it "hides the coverage editor from organisers of another organization" do
      sign_in_organiser_for(other_organization)

      get unit_path(unit)

      expect(response.body).not_to include(I18n.t("units.show.manage_coverage"))
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

      expect(response.body).not_to include(I18n.t("units.show.manage_coverage"))
    end
  end

  describe "attendee visibility" do
    let!(:unit) { create(:unit, program: program, instructor: create(:user, :admin)) }
    let!(:attendee) { create(:user, email: "attendee@example.com") }

    before { create(:unit_attendance, :attended, unit: unit, user: attendee) }

    it "hides attendees from plain users on the index page" do
      sign_in create(:user)

      get units_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(I18n.t("units.show.attendees"))
        expect(response.body).not_to include("attendee@example.com")
        expect(response.body).to include(unit.name)
      end
    end

    it "hides attendees from plain users on the detail page" do
      sign_in create(:user)

      get unit_path(unit)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(I18n.t("units.show.attendees"))
        expect(response.body).not_to include("attendee@example.com")
        expect(response.body).to include(I18n.t("units.show.covers"))
        expect(response.body).to include(I18n.l(unit.starts_at, format: :short))
      end
    end

    it "shows attendees to organisers on the detail page" do
      sign_in_organiser_for(organization)

      get unit_path(unit)

      aggregate_failures do
        expect(response.body).to include(I18n.t("units.show.attendees"))
        expect(response.body).to include("attendee@example.com")
      end
    end

    it "shows attendees to admins on the index page" do
      sign_in create(:user, :admin)

      get units_path

      aggregate_failures do
        expect(response.body).to include(I18n.t("units.index.table.attendees"))
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
