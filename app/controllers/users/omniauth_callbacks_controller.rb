module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      auth = request.env["omniauth.auth"]

      if auth.blank? || auth.provider.blank? || auth.uid.blank?
        redirect_with_alert(t(".invalid_request"))
        return
      end

      unless auth.info&.email.present?
        redirect_with_alert(t(".unverified_email"))
        return
      end

      unless GoogleOauth.allowed_email?(auth.info.email)
        redirect_with_alert(t(".domain_not_allowed"))
        return
      end

      if user_signed_in?
        link_current_user(auth)
      else
        sign_in_google_user(auth)
      end
    end

    def failure
      flash[:alert] = t(".failure", reason: failure_message)
      redirect_to user_signed_in? ? edit_user_registration_path : new_user_session_path
    end

    private

    def link_current_user(auth)
      unless current_user.email.casecmp?(auth.info.email)
        redirect_with_alert(
          t("users.omniauth_callbacks.google_oauth2.email_mismatch"),
          edit_user_registration_path
        )
        return
      end

      current_user.link_google!(auth)
      flash[:notice] = t("users.omniauth_callbacks.google_oauth2.linked")
      redirect_to edit_user_registration_path
    rescue User::GoogleLinkConflict, ActiveRecord::RecordNotUnique
      redirect_with_alert(
        t("users.omniauth_callbacks.google_oauth2.already_linked"),
        edit_user_registration_path
      )
    end

    def sign_in_google_user(auth)
      user = User.from_google_oauth2(auth)

      sign_in_and_redirect user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    rescue User::GoogleLinkConflict
      redirect_with_alert(t("users.omniauth_callbacks.google_oauth2.already_linked"))
    end

    def redirect_with_alert(message, path = nil)
      path ||= user_signed_in? ? edit_user_registration_path : new_user_session_path
      flash[:alert] = message
      redirect_to path
    end
  end
end
