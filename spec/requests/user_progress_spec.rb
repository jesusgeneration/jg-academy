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
        expect(response.body).to include("Unit Attendance")
      end
    end

    it "lists the user's attendance" do
      sign_in alice
      unit = create(:unit, name: "Youth Leadership Weekend")
      create(:unit_attendance, :attended, unit: unit, user: alice)

      get user_path(alice)

      aggregate_failures do
        expect(response.body).to include("Youth Leadership Weekend")
        expect(response.body).to include("Attended")
      end
    end

    it "forbids participants from viewing other users" do
      sign_in create(:user)

      get user_path(alice)

      expect(response).to redirect_to(root_path)
    end
  end
end
