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
