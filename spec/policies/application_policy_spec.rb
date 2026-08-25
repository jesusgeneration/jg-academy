require "rails_helper"
require "pundit/rspec"

RSpec.describe ApplicationPolicy do
  subject(:policy_class) { described_class }

  let(:record) { Object.new }

  permissions :index?, :show?, :new?, :create?, :edit?, :update?, :destroy? do
    it "grants admins every action" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), record)
    end

    it "denies plain users by default" do
      expect(policy_class).not_to permit(build_stubbed(:user), record)
    end

    it "denies organisation organisers by default" do
      user = build_stubbed(:user)
      allow(user).to receive(:organiser?).and_return(true)

      expect(policy_class).not_to permit(user, record)
    end
  end
end
