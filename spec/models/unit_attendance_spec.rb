require "rails_helper"

RSpec.describe UnitAttendance do
  describe "validations" do
    it "allows a user to attend a unit" do
      attendance = build(:unit_attendance)

      expect(attendance).to be_valid
    end

    it "prevents duplicate attendance for the same unit" do
      existing = create(:unit_attendance)
      duplicate = build(:unit_attendance, user: existing.user, unit: existing.unit)

      expect(duplicate).not_to be_valid
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "defaults to registered" do
      expect(described_class.new.status).to eq("registered")
    end

    it "allows non-attended statuses without a start time" do
      unit = create(:unit, starts_at: nil, ends_at: nil)

      expect(build(:unit_attendance, unit: unit, status: :registered)).to be_valid
    end

    it "requires a start time for attended" do
      unscheduled = create(:unit, starts_at: nil, ends_at: nil)
      attendance = build(:unit_attendance, unit: unscheduled, status: :attended)

      aggregate_failures do
        expect(attendance).not_to be_valid
        expect(attendance.errors[:status]).to include(
          I18n.t("activerecord.errors.models.unit_attendance.attributes.status.requires_start_time")
        )
      end
    end

    it "allows attended with only a start time" do
      unit = create(:unit, starts_at: 2.weeks.from_now, ends_at: nil)

      expect(build(:unit_attendance, unit: unit, status: :attended)).to be_valid
    end
  end

  describe "status enum" do
    it "defines all statuses" do
      expect(UnitAttendance.statuses).to eq(
        "registered" => 0,
        "attended" => 1,
        "cancelled" => 2,
        "no_show" => 3
      )
    end
  end

  describe "associations" do
    it "belongs to user and unit" do
      association = described_class.reflect_on_association(:user)
      unit_association = described_class.reflect_on_association(:unit)

      expect(association.macro).to eq(:belongs_to)
      expect(unit_association.macro).to eq(:belongs_to)
    end
  end
end
