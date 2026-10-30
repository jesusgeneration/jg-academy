require "rails_helper"
require "pundit/rspec"

RSpec.describe UnitPolicy do
  subject(:policy_class) { described_class }

  let(:organization) { create(:organization, name: "Church A") }
  let(:other_organization) { create(:organization, name: "Church B") }
  let(:program) { build_stubbed(:program, organization: organization) }
  let(:unit) { build_stubbed(:unit, program: program) }
  let(:user) { build_stubbed(:user) }

  permissions :index?, :show? do
    it "are open to everyone" do
      expect(policy_class).to permit(user, unit)
    end
  end

  permissions :new?, :create? do
    it "grant admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), unit)
    end

    it "grant users who organise any organization" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organiser?).and_return(true)

      expect(policy_class).to permit(organiser, unit)
    end

    it "deny plain users" do
      expect(policy_class).not_to permit(user, unit)
    end
  end

  permissions :update?, :destroy?, :view_attendees?, :inherit_attendances? do
    it "grant admins" do
      expect(policy_class).to permit(build_stubbed(:user, :admin), unit)
    end

    it "grant organisers of the unit's organization" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organises?).with(program.organization_id).and_return(true)

      expect(policy_class).to permit(organiser, unit)
    end

    it "deny organisers of a different organization" do
      other_organiser = build_stubbed(:user)
      allow(other_organiser).to receive(:organises?).with(program.organization_id).and_return(false)

      aggregate_failures do
        expect(policy_class).not_to permit(other_organiser, unit)
        expect(policy_class).not_to permit(user, unit)
      end
    end
  end

  permissions :view_attendance_summary? do
    it "grants admins and organisation organisers" do
      organiser = build_stubbed(:user)
      allow(organiser).to receive(:organiser?).and_return(true)

      aggregate_failures do
        expect(policy_class).to permit(build_stubbed(:user, :admin), Unit)
        expect(policy_class).to permit(organiser, Unit)
      end
    end

    it "denies plain users" do
      expect(policy_class).not_to permit(user, Unit)
    end
  end

  permissions :change_instructor? do
    let(:policy_organization) { create(:organization) }
    let(:policy_program) { create(:program, organization: policy_organization) }
    let(:instructor) do
      user = create(:user)
      create(:organization_membership, :organiser, user: user, organization: policy_organization)
      user
    end
    let(:fellow_organiser) do
      user = create(:user)
      create(:organization_membership, :organiser, user: user, organization: policy_organization)
      user
    end

    it "permits everyone when nobody attended yet" do
      unit = create(:unit, program: policy_program, instructor: instructor)

      aggregate_failures do
        expect(policy_class).to permit(create(:user, :admin), unit)
        expect(policy_class).to permit(create(:user), unit)
      end
    end

    it "permits the current instructor and admins once somebody attended" do
      unit = create(:unit, program: policy_program, instructor: instructor)
      create(:unit_attendance, :attended, unit: unit, user: create(:user))

      aggregate_failures do
        expect(policy_class).to permit(create(:user, :admin), unit)
        expect(policy_class).to permit(instructor, unit)
      end
    end

    it "denies other users once somebody attended" do
      unit = create(:unit, program: policy_program, instructor: instructor)
      create(:unit_attendance, :attended, unit: unit, user: create(:user))

      aggregate_failures do
        expect(policy_class).not_to permit(create(:user), unit)
        expect(policy_class).not_to permit(fellow_organiser, unit)
      end
    end
  end
end
