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

  describe "sign-up with jg email domain" do
    let(:valid_params) do
      { user: { email: "neu@jesusgeneration.de", password: "sup3rsecret!", password_confirmation: "sup3rsecret!", locale: "de" } }
    end

    it "shows the hint and prefilled domain on the sign-up page" do
      get new_user_registration_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("devise_views.registrations.new.email_hint"))
        expect(response.body).to include("@jesusgeneration.de")
      end
    end

    it "registers a user with a jesusgeneration.de address" do
      expect {
        post user_registration_path, params: valid_params
      }.to change(User, :count).by(1)

      aggregate_failures do
        expect(User.last.email).to eq("neu@jesusgeneration.de")
        expect(User.last).not_to be_confirmed
        expect(response).to have_http_status(:redirect)
      end
    end

    it "rejects other email domains" do
      expect {
        post user_registration_path, params: {
          user: valid_params[:user].merge(email: "neu@example.com")
        }
      }.not_to change(User, :count)

      aggregate_failures do
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(I18n.t("activerecord.errors.models.user.attributes.email.jg_only"))
      end
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
