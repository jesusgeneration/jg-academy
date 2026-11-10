require "rails_helper"

RSpec.describe "Google sign-in" do
  let(:callback_path) { user_google_oauth2_omniauth_callback_path }

  describe "sign-in page" do
    it "shows the Google button" do
      get new_user_session_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("devise_views.sessions.new.google_sign_in"))
        expect(response.body).to include(user_google_oauth2_omniauth_authorize_path)
        expect(response.body).to match(/<form[^>]+data-turbo="false"/)
      end
    end
  end

  describe "authorize request" do
    it "starts the Google OAuth flow with a POST" do
      post user_google_oauth2_omniauth_authorize_path

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(user_google_oauth2_omniauth_callback_path)
    end
  end

  describe "callback" do
    it "links an existing user by email and signs them in" do
      user = create(:user, email: "person@jesusgeneration.de")
      mock_google_auth(email: user.email, uid: "google-123")

      expect { post callback_path }.not_to change(User, :count)

      aggregate_failures do
        expect(response).to redirect_to(root_path)
        expect(user.reload).to have_attributes(provider: "google_oauth2", uid: "google-123")
      end
    end

    it "creates and signs in a new user with an allowed email" do
      mock_google_auth(email: "new@jesusgeneration.de", uid: "google-new")

      expect { post callback_path }.to change(User, :count).by(1)

      user = User.find_by(email: "new@jesusgeneration.de")

      aggregate_failures do
        expect(response).to redirect_to(root_path)
        expect(user).to be_confirmed
        expect(user).to have_attributes(provider: "google_oauth2", uid: "google-new")
      end
    end

    it "signs in an already linked user" do
      create(:user, :google, email: "person@jesusgeneration.de", uid: "google-123")
      mock_google_auth(email: "person@jesusgeneration.de", uid: "google-123")

      post callback_path

      expect(response).to redirect_to(root_path)

      follow_redirect!
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:ok)
    end

    it "rejects a Google account from another domain" do
      mock_google_auth(email: "person@gmail.com", uid: "google-123")

      expect { post callback_path }.not_to change(User, :count)

      aggregate_failures do
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.google_oauth2.domain_not_allowed"))
      end
    end

    it "rejects an unverified Google email" do
      mock_google_auth(email: "person@jesusgeneration.de", email_verified: false)

      expect { post callback_path }.not_to change(User, :count)

      aggregate_failures do
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.google_oauth2.unverified_email"))
      end
    end

    it "rejects a Google identity already linked to another account" do
      create(:user, :google, email: "person@jesusgeneration.de", uid: "google-old")
      mock_google_auth(email: "person@jesusgeneration.de", uid: "google-new")

      post callback_path

      aggregate_failures do
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.google_oauth2.already_linked"))
      end
    end

    it "redirects to sign-in with an alert when Google authentication fails" do
      allow(OmniAuth.config.logger).to receive(:error)
      OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials

      expect { post callback_path }.not_to change(User, :count)

      aggregate_failures do
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "linking a signed-in account" do
    it "links Google when the email matches" do
      user = create(:user, email: "person@jesusgeneration.de")
      sign_in user
      mock_google_auth(email: user.email, uid: "google-123")

      post callback_path

      aggregate_failures do
        expect(response).to redirect_to(edit_user_registration_path)
        expect(user.reload).to have_attributes(provider: "google_oauth2", uid: "google-123")
        expect(flash[:notice]).to eq(I18n.t("users.omniauth_callbacks.google_oauth2.linked"))
      end
    end

    it "rejects a Google email that does not match the account email" do
      user = create(:user, email: "person@jesusgeneration.de")
      sign_in user
      mock_google_auth(email: "other@jesusgeneration.de", uid: "google-123")

      post callback_path

      aggregate_failures do
        expect(response).to redirect_to(edit_user_registration_path)
        expect(user.reload.provider).to be_nil
        expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.google_oauth2.email_mismatch"))
      end
    end

    it "rejects a disallowed Google domain and returns to the profile" do
      user = create(:user, email: "person@jesusgeneration.de")
      sign_in user
      mock_google_auth(email: "person@gmail.com", uid: "google-123")

      post callback_path

      aggregate_failures do
        expect(response).to redirect_to(edit_user_registration_path)
        expect(user.reload.provider).to be_nil
        expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.google_oauth2.domain_not_allowed"))
      end
    end

    it "rejects a different Google identity for an already linked account" do
      user = create(:user, :google, email: "person@jesusgeneration.de", uid: "google-old")
      sign_in user
      mock_google_auth(email: user.email, uid: "google-new")

      post callback_path

      aggregate_failures do
        expect(response).to redirect_to(edit_user_registration_path)
        expect(user.reload.uid).to eq("google-old")
        expect(flash[:alert]).to eq(I18n.t("users.omniauth_callbacks.google_oauth2.already_linked"))
      end
    end
  end

  describe "profile page" do
    it "shows the connected state for a linked account" do
      sign_in create(:user, :google, email: "person@jesusgeneration.de")

      get edit_user_registration_path

      expect(response.body).to include(I18n.t("devise_views.registrations.edit.google_connected"))
    end

    it "shows the connect button for an unlinked account" do
      sign_in create(:user, email: "person@jesusgeneration.de")

      get edit_user_registration_path

      expect(response.body).to include(I18n.t("devise_views.registrations.edit.connect_google"))
    end
  end
end
