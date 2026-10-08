require "rails_helper"

RSpec.describe "Dashboard" do
  describe "GET /dashboard" do
    context "as admin" do
      it "shows portal statistics" do
        sign_in create(:user, :admin)
        create(:user)
        create(:unit)

        get dashboard_path

        aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(I18n.t("dashboards.show.recent_units"))
        end
      end

      it "shows upcoming programs ordered by next date with green/grey date badges" do
        sign_in create(:user, :admin)
        sooner_program = create(:program, name: "Sooner Program XYZ")
        create(:unit, program: sooner_program, starts_at: 1.day.from_now, ends_at: 2.days.from_now)
        later_program = create(:program, name: "Later Program XYZ")
        create(:unit, program: later_program, starts_at: 10.days.from_now, ends_at: 11.days.from_now)
        past_only_program = create(:program, name: "Past Only Program XYZ")
        create(:unit, :past, program: past_only_program)
        create(:unit, :past)

        get dashboard_path

        aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(I18n.t("dashboards.show.recent_programs"))
          expect(response.body).to include(I18n.t("dashboards.show.table.units"))
          expect(response.body).to include(sooner_program.name)
          expect(response.body).to include(later_program.name)
          expect(response.body).not_to include(past_only_program.name)
          expect(response.body.index(sooner_program.name)).to be < response.body.index(later_program.name)
          expect(response.body).to include("badge-success")
          expect(response.body).to include("badge-ghost")
        end
      end
    end

    context "as organisation organiser" do
      it "is accessible" do
        user = create(:user)
        create(:organization_membership, :organiser, user: user)
        sign_in user

        get dashboard_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "as plain user" do
      it "redirects to their own progress page" do
        user = create(:user)
        sign_in user

        get dashboard_path

        expect(response).to redirect_to(user_path(user))
      end
    end
  end
end
