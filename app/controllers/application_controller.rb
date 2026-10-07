class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  layout :determine_layout

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def default_url_options
    return {} if I18n.locale == I18n.default_locale

    { locale: I18n.locale }
  end

  private

  def set_locale
    requested = locale_from_params || locale_from_user || locale_from_session || locale_from_header || I18n.default_locale
    I18n.locale = requested if I18n.available_locales.map(&:to_s).include?(requested.to_s)

    session[:locale] = I18n.locale.to_s
    persist_user_locale if user_signed_in? && current_user.locale != I18n.locale.to_s && locale_from_params
  end

  def locale_from_params
    params[:locale] if params[:locale].present? && User::LOCALES.include?(params[:locale].to_s)
  end

  def locale_from_user
    current_user&.locale if user_signed_in?
  end

  def locale_from_session
    session[:locale] if session[:locale].present? && User::LOCALES.include?(session[:locale].to_s)
  end

  def locale_from_header
    parsed = request.env["HTTP_ACCEPT_LANGUAGE"]&.scan(/^[a-z]{2}/)&.first
    parsed if parsed.present? && User::LOCALES.include?(parsed)
  end

  def persist_user_locale
    current_user.update(locale: I18n.locale.to_s)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[locale])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[locale])
  end

  def determine_layout
    devise_controller? ? "devise" : "application"
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:alert] = I18n.t("#{policy_name}.#{exception.query}", scope: "pundit", default: :default)
    redirect_back fallback_location: root_path
  end
end
