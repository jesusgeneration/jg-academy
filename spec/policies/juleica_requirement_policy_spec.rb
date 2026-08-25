require "rails_helper"
require "pundit/rspec"

RSpec.describe JuleicaRequirementPolicy do
  subject(:policy_class) { described_class }

  let(:requirement) { build_stubbed(:juleica_requirement) }

  permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
    it "grants admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), requirement)
    end

    it "denies participants and organisers" do
      aggregate_failures do
        expect(policy_class).not_to permit(build_stubbed(:user), requirement)
        expect(policy_class).not_to permit(build_stubbed(:user), requirement)
      end
    end
  end
end
