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

  describe "Google OAuth" do
    let(:email) { "person@jesusgeneration.de" }

    it "links an existing account by matching email" do
      user = create(:user, email: email)
      auth = build_google_auth(email: email, uid: "google-123")

      expect { @result = described_class.from_google_oauth2(auth) }.not_to change(User, :count)

      aggregate_failures do
        expect(@result).to eq(user)
        expect(user.reload).to have_attributes(provider: "google_oauth2", uid: "google-123")
        expect(user).to be_google_linked
        expect(user).to be_confirmed
      end
    end

    it "confirms an existing unconfirmed account" do
      user = create(:user, :unconfirmed, email: email)

      described_class.from_google_oauth2(build_google_auth(email: email))

      expect(user.reload).to be_confirmed
    end

    it "creates a confirmed account for a new allowed email" do
      auth = build_google_auth(email: "new@jesusgeneration.de", uid: "google-new")

      expect { @user = described_class.from_google_oauth2(auth) }.to change(User, :count).by(1)

      aggregate_failures do
        expect(@user).to be_confirmed
        expect(@user).to have_attributes(
          email: "new@jesusgeneration.de",
          provider: "google_oauth2",
          uid: "google-new"
        )
        expect(@user.valid_password?("anything")).to be(false)
      end
    end

    it "finds a linked account by uid even when the Google email changed" do
      user = create(:user, :google, email: "old@jesusgeneration.de", uid: "google-123")

      result = described_class.from_google_oauth2(
        build_google_auth(email: "new@jesusgeneration.de", uid: "google-123")
      )

      expect(result).to eq(user)
    end

    it "refuses to relink an account to a different Google identity" do
      user = create(:user, :google, email: email, uid: "google-old")

      expect {
        described_class.from_google_oauth2(build_google_auth(email: email, uid: "google-new"))
      }.to raise_error(User::GoogleLinkConflict)

      expect(user.reload.uid).to eq("google-old")
    end

    it "requires provider and uid to be present together" do
      aggregate_failures do
        expect(build(:user, provider: "google_oauth2")).not_to be_valid
        expect(build(:user, uid: "google-123")).not_to be_valid
      end
    end

    it "enforces a unique uid per provider" do
      create(:user, :google, uid: "google-123")

      expect(build(:user, :google, uid: "google-123")).not_to be_valid
    end

    it "enforces provider and uid pairing at the database level" do
      user = build(:user, provider: "google_oauth2", uid: nil)

      expect { user.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "enforces uid uniqueness at the database level" do
      create(:user, :google, uid: "google-123")
      duplicate = build(:user, :google, uid: "google-123")

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
