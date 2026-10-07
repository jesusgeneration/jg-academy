require "rails_helper"

RSpec.describe "Locale handling" do
  it "defaults to German" do
    expect(I18n.default_locale).to eq(:de)
    expect(I18n.available_locales).to include(:en, :de)
  end

  it "renders German by default" do
    get new_user_session_path

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("devise_views.sessions.new.title", locale: :de))
      expect(response.body).to include('lang="de"')
    end
  end

  it "renders English with locale param and persists it in the session" do
    get new_user_session_path(locale: "en")

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("devise_views.sessions.new.title", locale: :en))
      expect(response.body).to include('lang="en"')
    end

    get new_user_session_path

    expect(response.body).to include(I18n.t("devise_views.sessions.new.title", locale: :en))
  end

  it "persists the requested locale on the signed-in user" do
    user = create(:user, locale: "de")
    sign_in user

    get programs_path(locale: "en")

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("programs.index.title", locale: :en))
      expect(user.reload.locale).to eq("en")
    end
  end

  it "uses the stored user locale without a param" do
    user = create(:user, locale: "en")
    sign_in user

    get programs_path

    expect(response.body).to include(I18n.t("programs.index.title", locale: :en))
  end

  it "ignores unknown locales and falls back to German" do
    get new_user_session_path(locale: "fr")

    expect(response.body).to include(I18n.t("devise_views.sessions.new.title", locale: :de))
  end

  it "shows a language switcher" do
    get new_user_session_path(locale: "de")

    aggregate_failures do
      expect(response.body).to include('href="/auth/sign_in?locale=en"')
      expect(response.body).to include(">EN<")
      expect(response.body).to include(">DE<")
    end
  end

  it "translates controller notices" do
    sign_in create(:user, :admin)

    post organizations_path, params: { organization: { name: "St. Peter's" } }
    follow_redirect!

    expect(response.body).to include(I18n.t("organizations.create.created"))
  end

  it "has matching English and German keys" do
    scopes = %w[languages layouts dashboards organizations programs units unit_attendances unit_coverages users helpers.coverage pundit devise_views]
    scopes.each do |scope|
      en_sub = I18n.t(scope, locale: :en)
      de_sub = I18n.t(scope, locale: :de)
      expect(flatten_keys(de_sub)).to match_array(flatten_keys(en_sub)), "mismatch in #{scope}"
    end

    expect(I18n.t("activerecord.enums", locale: :de).keys).to match_array(I18n.t("activerecord.enums", locale: :en).keys)
  end

  it "localizes dates" do
    sign_in create(:user)
    unit = create(:unit)

    get unit_path(unit)

    expect(response.body).to include(I18n.l(unit.starts_at, format: :short))
  end

  it "lets admins change a user's language" do
    sign_in create(:user, :admin)
    user = create(:user, locale: "de")

    patch user_path(user), params: { user: { locale: "en" } }

    expect(user.reload.locale).to eq("en")
  end

  it "lets users change their language in their profile" do
    user = create(:user, locale: "de", password: "sup3rsecret!", password_confirmation: "sup3rsecret!")
    sign_in user

    put user_registration_path, params: { user: { locale: "en", current_password: "sup3rsecret!" } }

    expect(user.reload.locale).to eq("en")
  end

  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) ? flatten_keys(value, full) : [ full ]
    end
  end
end
