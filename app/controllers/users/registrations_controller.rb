module Users
  class RegistrationsController < Devise::RegistrationsController
    JG_EMAIL_DOMAIN = "@jesusgeneration.de"

    def create
      email = sign_up_params[:email].to_s
      unless email.downcase.end_with?(JG_EMAIL_DOMAIN)
        self.resource = resource_class.new(sign_up_params)
        resource.errors.add(:email, :jg_only)
        render :new, status: :unprocessable_content
        return
      end

      super
    end
  end
end
