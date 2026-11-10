require "rails_helper"

RSpec.describe GoogleOauth do
  describe ".allowed_email?" do
    around do |example|
      previous = ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"]
      example.run
    ensure
      ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"] = previous
    end

    it "defaults to the jesusgeneration.de domain" do
      ENV.delete("GOOGLE_ALLOWED_EMAIL_DOMAINS")

      aggregate_failures do
        expect(described_class.allowed_email?("person@jesusgeneration.de")).to be(true)
        expect(described_class.allowed_email?("person@gmail.com")).to be(false)
      end
    end

    it "accepts configured domains, including an @ prefix" do
      ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"] = "@example.com, gmail.com"

      aggregate_failures do
        expect(described_class.allowed_email?("person@example.com")).to be(true)
        expect(described_class.allowed_email?("person@gmail.com")).to be(true)
        expect(described_class.allowed_email?("person@jesusgeneration.de")).to be(false)
      end
    end

    it "rejects addresses without a domain" do
      expect(described_class.allowed_email?("person")).to be(false)
      expect(described_class.allowed_email?(nil)).to be(false)
    end
  end

  describe ".hosted_domain" do
    around do |example|
      previous = ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"]
      example.run
    ensure
      ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"] = previous
    end

    it "returns the jg domain when it is the only allowed domain" do
      ENV.delete("GOOGLE_ALLOWED_EMAIL_DOMAINS")

      expect(described_class.hosted_domain).to eq("jesusgeneration.de")
    end

    it "does not set a hint for personal domains" do
      ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"] = "gmail.com"

      expect(described_class.hosted_domain).to be_nil
    end

    it "does not set a hint when several domains are allowed" do
      ENV["GOOGLE_ALLOWED_EMAIL_DOMAINS"] = "jesusgeneration.de,example.com"

      expect(described_class.hosted_domain).to be_nil
    end
  end
end
