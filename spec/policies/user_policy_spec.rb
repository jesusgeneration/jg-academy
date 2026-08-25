require "rails_helper"
require "pundit/rspec"

RSpec.describe UserPolicy do
  subject(:policy_class) { described_class }

  let(:user) { build_stubbed(:user) }
  let(:other_user) { build_stubbed(:user) }

  permissions :show? do
    it "permits users to view themselves" do
      expect(policy_class).to permit(user, user)
    end

    it "permits admins to view anyone" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), other_user)
    end

    it "denies participants from viewing other users" do
      expect(policy_class).not_to permit(user, other_user)
    end
  end

  permissions :index?, :new?, :create?, :edit?, :update?, :destroy? do
    it "are admin-only" do
      aggregate_failures do
        expect(policy_class).to permit(build_stubbed(:user, :admin), other_user)
        expect(policy_class).not_to permit(user, other_user)
        expect(policy_class).not_to permit(build_stubbed(:user), other_user)
      end
    end
  end
end
