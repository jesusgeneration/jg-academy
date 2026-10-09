require "rails_helper"
require "pundit/rspec"

RSpec.describe ProgramPolicy do
  subject(:policy_class) { described_class }

  let(:organization) { create(:organization, name: "Church A") }
  let(:other_organization) { create(:organization, name: "Church B") }
  let(:program) { build_stubbed(:program, organization: organization) }
  let(:user) { build_stubbed(:user) }

  permissions :index?, :show? do
    it "are open to everyone" do
      expect(policy_class).to permit(user, program)
    end
  end

  permissions :new?, :create? do
    it "grant admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), program)
    end

    it "grant users who organise any organization" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organiser?).and_return(true)

      expect(policy_class).to permit(organiser, program)
    end

    it "deny plain users" do
      expect(policy_class).not_to permit(user, program)
    end
  end

  permissions :update?, :destroy?, :view_attendees? do
    it "grant admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), program)
    end

    it "grant organisers of the program's organization" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organises?).with(program.organization_id).and_return(true)

      expect(policy_class).to permit(organiser, program)
    end

    it "deny organisers of a different organization" do
      other_organiser = build_stubbed(:user)
      allow(other_organiser).to receive(:organises?).with(program.organization_id).and_return(false)

      aggregate_failures do
        expect(policy_class).not_to permit(other_organiser, program)
        expect(policy_class).not_to permit(user, program)
      end
    end
  end
end
