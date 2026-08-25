require "rails_helper"
require "pundit/rspec"

RSpec.describe OrganizationPolicy do
  subject(:policy_class) { described_class }

  let(:organization) { build_stubbed(:organization) }

  permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
    it "grants admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), organization)
    end

    it "denies participants and organisers" do
      aggregate_failures do
        expect(policy_class).not_to permit(build_stubbed(:user), organization)
        expect(policy_class).not_to permit(build_stubbed(:user), organization)
      end
    end
  end
end
