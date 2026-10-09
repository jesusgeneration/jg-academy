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
      create(:unit_attendance, user: user)

      expect { user.destroy }.to change(OrganizationMembership, :count).by(-1)
        .and change(UnitAttendance, :count).by(-1)
    end
  end

  describe "eligible instructors" do
    it "marks admins and organisers as eligible" do
      organiser = create(:user)
      create(:organization_membership, :organiser, user: organiser)

      aggregate_failures do
        expect(create(:user, :admin)).to be_eligible_instructor
        expect(organiser).to be_eligible_instructor
        expect(create(:user)).not_to be_eligible_instructor
      end
    end

    it "scopes eligible instructors to admins and organisers" do
      admin = create(:user, :admin)
      organiser = create(:user)
      create(:organization_membership, :organiser, user: organiser)
      member = create(:user)
      create(:organization_membership, user: member, role: :member)
      plain = create(:user)

      expect(User.eligible_instructors).to contain_exactly(admin, organiser)
      expect(User.eligible_instructors).not_to include(member, plain)
    end
  end

  describe "locale" do
    it "defaults to German" do
      expect(User.new.locale).to eq("de")
      expect(create(:user, locale: nil).locale).to eq("de")
    end

    it "accepts English and German" do
      expect(build(:user, locale: "en")).to be_valid
      expect(build(:user, locale: "de")).to be_valid
    end

    it "rejects unknown locales" do
      expect(build(:user, locale: "fr")).not_to be_valid
    end
  end
end
