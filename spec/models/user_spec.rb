require "rails_helper"

RSpec.describe User do
  describe "roles" do
    it "defaults to user" do
      expect(create(:user).role).to eq("user")
    end

    it "supports admin role" do
      expect(build_stubbed(:user, :admin)).to be_admin
      expect(build_stubbed(:user, :admin)).to be_staff
    end

    it "treats users with an organiser membership as staff" do
      user = create(:user)
      create(:organization_membership, :organiser, user: user)

      aggregate_failures do
        expect(user).to be_organiser
        expect(user).to be_staff
      end
    end

    it "scopes organising rights to specific organizations" do
      church_a = create(:organization, name: "Church A")
      church_b = create(:organization, name: "Church B")
      user = create(:user)
      create(:organization_membership, :organiser, user: user, organization: church_a)

      aggregate_failures do
        expect(user).to be_organises(church_a)
        expect(user).not_to be_organises(church_b)
      end
    end
  end

  describe "#juleica_progress" do
    let(:user) { create(:user) }

    it "returns progress results for all requirements" do
      create(:juleica_requirement, name: "Group Leadership", required_hours: 8)

      results = user.juleica_progress

      expect(results.size).to eq(1)
      result = results.first
      aggregate_failures do
        expect(result.requirement.name).to eq("Group Leadership")
        expect(result.required_hours).to eq(8)
        expect(result.earned_hours).to eq(0)
        expect(result.remaining_hours).to eq(8)
        expect(result).not_to be_completed
      end
    end
  end

  describe "associations" do
    it "destroys memberships and attendances with the user" do
      user = create(:user)
      create(:organization_membership, user: user)
      create(:course_attendance, user: user)

      expect { user.destroy }.to change(OrganizationMembership, :count).by(-1)
        .and change(CourseAttendance, :count).by(-1)
    end
  end
end
