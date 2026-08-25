require "rails_helper"

RSpec.describe "Dashboard" do
  describe "GET /dashboard" do
    context "as admin" do
      it "shows portal statistics" do
        sign_in create(:user, :admin)
        create(:user)
        create(:course)
        create(:juleica_requirement)

        get dashboard_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Users Close to Juleica")
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
