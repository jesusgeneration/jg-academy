require "rails_helper"
require "pundit/rspec"

RSpec.describe CoursePolicy do
  subject(:policy_class) { described_class }

  let(:organization) { create(:organization, name: "Church A") }
  let(:other_organization) { create(:organization, name: "Church B") }
  let(:course) { build_stubbed(:course, organization: organization) }
  let(:user) { build_stubbed(:user) }

  permissions :index?, :show? do
    it "are open to everyone" do
      expect(policy_class).to permit(user, course)
    end
  end

  permissions :new?, :create? do
    it "grant admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), course)
    end

    it "grant users who organise any organization" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organiser?).and_return(true)

      expect(policy_class).to permit(organiser, course)
    end

    it "deny plain users" do
      expect(policy_class).not_to permit(user, course)
    end
  end

  permissions :update?, :destroy?, :view_attendees? do
    it "grant admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), course)
    end

    it "grant organisers of the course's organization" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organises?).with(course.organization_id).and_return(true)

      expect(policy_class).to permit(organiser, course)
    end

    it "deny organisers of a different organization" do
      other_organiser = build_stubbed(:user)
      allow(other_organiser).to receive(:organises?).with(course.organization_id).and_return(false)

      aggregate_failures do
        expect(policy_class).not_to permit(other_organiser, course)
        expect(policy_class).not_to permit(user, course)
      end
    end
  end

  permissions :view_attendance_summary? do
    it "grants admins and organisation organisers" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organiser?).and_return(true)

      aggregate_failures do
        expect(policy_class).to permit(build_stubbed(:user, :admin), Course)
        expect(policy_class).to permit(organiser, Course)
      end
    end

    it "denies plain users" do
      expect(policy_class).not_to permit(user, Course)
    end
  end
end
