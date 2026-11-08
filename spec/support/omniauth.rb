OmniAuth.config.test_mode = true

module OmniauthHelpers
  def build_google_auth(email:, uid: "google-uid-1", email_verified: true, hosted_domain: "jesusgeneration.de")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: {
        email: email_verified ? email : nil,
        unverified_email: email,
        email_verified: email_verified,
        name: "Test Person"
      },
      extra: {
        id_info: {
          email: email,
          email_verified: email_verified,
          hd: hosted_domain
        }.compact
      }
    )
  end

  def mock_google_auth(**options)
    OmniAuth.config.mock_auth[:google_oauth2] = build_google_auth(**options)
  end
end

RSpec.configure do |config|
  config.include OmniauthHelpers

  config.after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end
end
