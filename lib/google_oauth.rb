module GoogleOauth
  PROVIDER = "google_oauth2"
  DEFAULT_DOMAIN = "jesusgeneration.de"

  module_function

  def configured?
    client_id.present? && client_secret.present?
  end

  def client_id
    ENV["GOOGLE_CLIENT_ID"].presence || credentials.dig(:google_oauth, :client_id)
  end

  def client_secret
    ENV["GOOGLE_CLIENT_SECRET"].presence || credentials.dig(:google_oauth, :client_secret)
  end

  def allowed_domains
    raw = ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"].presence
    return parse_domains(raw) if raw

    [ DEFAULT_DOMAIN ]
  end

  def allowed_email?(email)
    domain = email.to_s.split("@").last.to_s.downcase
    return false if domain.blank?

    allowed_domains.include?(domain)
  end

  # Passed to Google as the `hd` authorization hint. The server-side
  # allowed_email? check remains the authoritative gate. Only set it for the
  # real Workspace domain: personal accounts (e.g. gmail.com) have no hd claim.
  def hosted_domain
    DEFAULT_DOMAIN if allowed_domains == [ DEFAULT_DOMAIN ]
  end

  def parse_domains(raw)
    raw.to_s.split(",").map { |domain| domain.strip.downcase.delete_prefix("@") }.reject(&:empty?)
  end

  def credentials
    Rails.application.credentials
  end
end
