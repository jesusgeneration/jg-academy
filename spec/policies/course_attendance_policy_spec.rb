require "rails_helper"
require "pundit/rspec"

RSpec.describe CourseAttendancePolicy do
  subject(:policy_class) { described_class }

  let(:organization) { create(:organization, name: "Church A") }
  let(:other_organization) { create(:organization, name: "Church B") }
  let!(:attendance) { create(:course_attendance, course: create(:course, organization: organization)) }
  let(:user) { build_stubbed(:user) }

  permissions :create?, :update?, :destroy? do
    it "grant admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), attendance)
    end

    it "grant organisers of the course's organization" do
      organiser = create(:user)
      create(:organization_membership, :organiser, user: organiser, organization: organization)

      expect(policy_class).to permit(organiser, attendance)
    end

    it "deny organisers of a different organization and plain users" do
      other_organiser = create(:user)
      create(:organization_membership, :organiser, user: other_organiser, organization: other_organization)

      aggregate_failures do
        expect(policy_class).not_to permit(other_organiser, attendance)
        expect(policy_class).not_to permit(user, attendance)
      end
    end
  end
end
