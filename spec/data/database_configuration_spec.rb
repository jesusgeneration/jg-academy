require "rails_helper"
require "erb"
require "yaml"

RSpec.describe "Database configuration" do
  def configurations
    yaml = ERB.new(Rails.root.join("config/database.yml").read).result
    ActiveRecord::DatabaseConfigurations.new(YAML.safe_load(yaml, aliases: true))
  end

  it "uses the explicit test URL instead of the development DATABASE_URL" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DATABASE_URL").and_return("postgres://postgres:password@postgres:5432/jg_lead_development")
    allow(ENV).to receive(:[]).with("TEST_DATABASE_URL").and_return("postgres://postgres:password@postgres:5432/jg_lead_test")

    expect(configurations.configs_for(env_name: "development").first.database).to eq("jg_lead_development")
    expect(configurations.configs_for(env_name: "test").first.database).to eq("jg_lead_test")
  end

  it "keeps separate database names for a connection-only URL as used in CI" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DATABASE_URL").and_return("postgres://postgres:postgres@localhost:5432")
    allow(ENV).to receive(:[]).with("TEST_DATABASE_URL").and_return(nil)

    expect(configurations.configs_for(env_name: "development").first.database).to eq("jg_lead_development")
    expect(configurations.configs_for(env_name: "test").first.database).to eq("jg_lead_test")
  end
end
