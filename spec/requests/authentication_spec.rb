require "rails_helper"

RSpec.describe "Authentication" do
  it "redirects anonymous visitors to the sign-in page" do
    get units_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "allows a confirmed user to sign in" do
    user = create(:user)

    post user_session_path, params: { user: { email: user.email, password: "sup3rsecret!" } }

    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).not_to include(I18n.t("devise_views.sessions.new.submit"))
  end

  it "shows the portal shell after sign-in" do
    sign_in create(:user, :admin)

    get root_path

    aggregate_failures do
      expect(response.body).to include("jg-academy")
      expect(response.body).to include(I18n.t("layouts.application.nav.dashboard"))
      expect(response.body).to match(%r{Logo(-\w+)?.svg})
    end
  end

  describe "auth pages render through the devise layout" do
    it "renders the sign-in page" do
      get new_user_session_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("devise_views.sessions.new.title"))
        expect(response.body).to include("jg-academy")
        expect(response.body).to match(%r{Logo(-\w+)?.svg})
      end
    end

    it "renders the sign-up page" do
      get new_user_registration_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the forgot-password page" do
      get new_user_password_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the resend-confirmation page" do
      get new_user_confirmation_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the registration edit page while signed in" do
      sign_in create(:user)

      get edit_user_registration_path

      expect(response).to have_http_status(:ok)
    end
  end
end
