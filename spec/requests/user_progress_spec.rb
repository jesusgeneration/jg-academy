require "rails_helper"

RSpec.describe "Users" do
  describe "GET /users/:id" do
    let(:admin) { create(:user, :admin) }
    let(:alice) { create(:user, email: "alice@example.com") }

    it "shows a user to admins" do
      sign_in admin

      get user_path(alice)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("alice@example.com")
      end
    end

    it "lets participants view their own page" do
      sign_in alice

      get user_path(alice)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("alice@example.com")
        expect(response.body).to include(I18n.t("users.show.attendance_title"))
      end
    end

    it "lists the user's attendance" do
      sign_in alice
      unit = create(:unit, name: "Youth Leadership Weekend", instructor: create(:user, :admin))
      create(:unit_attendance, :attended, unit: unit, user: alice)

      get user_path(alice)

      aggregate_failures do
        expect(response.body).to include("Youth Leadership Weekend")
        expect(response.body).to include(I18n.t("activerecord.enums.unit_attendance.status.attended"))
      end
    end

    it "shows topic progress as covered details versus all details" do
      sign_in alice
      level = create(:content, :level, title: "Topic Area Progress")
      section = create(:content, :section, parent: level, title: "Topic Progress")
      details = create_list(:content, 3, :detail, parent: section)
      unit = create(:unit, instructor: create(:user, :admin))
      create(:unit_coverage, unit: unit, content: details.first)
      create(:unit_attendance, :attended, unit: unit, user: alice)

      get user_path(alice)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("users.show.progress_title"))
        expect(response.body).to include("Topic Area Progress")
        expect(response.body).to include("Topic Progress")
        expect(response.body).to include(I18n.t("users.show.progress_count", covered: 1, total: 3))
        expect(response.body).to include("collapse")
      end
    end

    it "counts ancestor coverage as covered details without modification" do
      sign_in alice
      level = create(:content, :level)
      full = create(:content, :section, parent: level)
      create_list(:content, 2, :detail, parent: full)
      partial = create(:content, :section, parent: level)
      partial_details = create_list(:content, 3, :detail, parent: partial)
      unit = create(:unit, instructor: create(:user, :admin))
      create(:unit_coverage, unit: unit, content: full)
      create(:unit_coverage, unit: unit, content: partial_details.first)
      create(:unit_attendance, :attended, unit: unit, user: alice)

      get user_path(alice)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("users.show.progress_count", covered: 3, total: 5))
      end
    end

    it "ignores non-attended units for progress" do
      sign_in alice
      level = create(:content, :level)
      section = create(:content, :section, parent: level)
      detail = create(:content, :detail, parent: section)
      unit = create(:unit, instructor: create(:user, :admin))
      create(:unit_coverage, unit: unit, content: detail)
      create(:unit_attendance, unit: unit, user: alice, status: :registered)

      get user_path(alice)

      expect(response.body).to include(I18n.t("users.show.progress_count", covered: 0, total: 1))
    end

    it "shows training hours toward the 50 hour goal" do
      sign_in alice
      unit = create(:unit,
        instructor: create(:user, :admin),
        starts_at: Time.zone.local(2026, 10, 10, 10, 0),
        ends_at: Time.zone.local(2026, 10, 10, 12, 0))
      create(:unit_attendance, :attended, unit: unit, user: alice)

      get user_path(alice)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("users.show.training_title"))
        expect(response.body).to include(I18n.t("users.show.training_value", hours: "2", goal: 50))
        expect(response.body).to include('value="4"')
      end
    end

    it "ignores units without durations for training hours" do
      sign_in alice
      unit = create(:unit, instructor: create(:user, :admin), starts_at: 2.weeks.from_now, ends_at: nil)
      create(:unit_attendance, :attended, unit: unit, user: alice)

      get user_path(alice)

      expect(response.body).to include(I18n.t("users.show.training_value", hours: "0", goal: 50))
    end

    it "forbids participants from viewing other users" do
      sign_in create(:user)

      get user_path(alice)

      expect(response).to redirect_to(root_path)
    end
  end
end
