class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :determine_layout

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def determine_layout
    devise_controller? ? "devise" : "application"
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:alert] = I18n.t("#{policy_name}.#{exception.query}", scope: "pundit", default: :default)
    redirect_back fallback_location: root_path
  end
end
