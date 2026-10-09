require "rails_helper"

RSpec.describe Unit do
  describe "validations" do
    it "requires a name and program" do
      expect(build(:unit)).to be_valid
      expect(build(:unit, name: nil)).not_to be_valid
      expect(build(:unit, program: nil)).not_to be_valid
    end

    it "allows unscheduled units without dates" do
      expect(build(:unit, starts_at: nil, ends_at: nil)).to be_valid
    end

    it "rejects end before start" do
      unit = build(:unit, starts_at: 2.weeks.from_now, ends_at: 1.week.from_now)

      expect(unit).not_to be_valid
    end
  end

  describe "scheduling" do
    it "reports unscheduled units" do
      aggregate_failures do
        expect(build(:unit, starts_at: nil, ends_at: nil)).not_to be_scheduled
        expect(build(:unit)).to be_scheduled
      end
    end

    it "is never past without an end time" do
      expect(build(:unit, starts_at: nil, ends_at: nil).past?).to be(false)
    end
  end

  describe "split datetime fields" do
    it "composes starts_at from date and time" do
      unit = build(:unit, starts_at: nil, ends_at: nil,
        start_date: "2026-10-10", start_time: "18:15")

      expect(unit).to be_valid
      expect(unit.starts_at).to eq(Time.zone.local(2026, 10, 10, 18, 15))
    end

    it "leaves starts_at blank for incomplete parts" do
      unit = build(:unit, starts_at: nil, ends_at: nil,
        start_date: "2026-10-10", start_time: "")

      aggregate_failures do
        expect(unit).to be_valid
        expect(unit.starts_at).to be_nil
      end
    end

    it "leaves starts_at blank for unparsable input" do
      unit = build(:unit, starts_at: nil, ends_at: nil,
        start_date: "not-a-date", start_time: "18:15")

      aggregate_failures do
        expect(unit).to be_valid
        expect(unit.starts_at).to be_nil
      end
    end
  end

  describe "duration_minutes" do
    it "computes ends_at from starts_at" do
      unit = build(:unit, starts_at: Time.zone.local(2026, 10, 10, 18, 0), ends_at: nil, duration_minutes: "30")

      expect(unit).to be_valid
      expect(unit.ends_at).to eq(Time.zone.local(2026, 10, 10, 18, 30))
    end

    it "supports hour-minute durations like 1:15" do
      unit = build(:unit, starts_at: Time.zone.local(2026, 10, 10, 18, 0), ends_at: nil, duration_minutes: "75")

      expect(unit).to be_valid
      expect(unit.ends_at).to eq(Time.zone.local(2026, 10, 10, 19, 15))
    end

    it "overrides an explicitly given ends_at" do
      unit = build(:unit, starts_at: Time.zone.local(2026, 10, 10, 18, 0),
        ends_at: Time.zone.local(2026, 10, 12, 18, 0), duration_minutes: "45")

      expect(unit).to be_valid
      expect(unit.ends_at).to eq(Time.zone.local(2026, 10, 10, 18, 45))
    end

    it "leaves ends_at untouched when blank" do
      starts_at = Time.zone.local(2026, 10, 10, 18, 0)
      ends_at = Time.zone.local(2026, 10, 10, 20, 0)
      unit = build(:unit, starts_at: starts_at, ends_at: ends_at, duration_minutes: "")

      expect(unit).to be_valid
      expect(unit.ends_at).to eq(ends_at)
    end

    it "leaves ends_at blank for duration without starts_at" do
      unit = build(:unit, starts_at: nil, ends_at: nil, duration_minutes: "30")

      aggregate_failures do
        expect(unit).to be_valid
        expect(unit.ends_at).to be_nil
      end
    end
  end

  describe "organization delegation" do
    it "delegates to the program" do
      program = create(:program)
      unit = create(:unit, program: program)

      expect(unit.organization).to eq(program.organization)
    end
  end

  describe "scopes" do
    let!(:upcoming_unit) { create(:unit) }
    let!(:past_unit) { create(:unit, :past) }

    it ".upcoming returns units ending in the future" do
      expect(Unit.upcoming).to contain_exactly(upcoming_unit)
    end

    it ".past returns units already finished" do
      expect(Unit.past).to contain_exactly(past_unit)
    end
  end

  describe "associations" do
    it "destroys attendances and coverages with the unit" do
      unit = create(:unit)
      create(:unit_attendance, unit: unit)
      create(:unit_coverage, unit: unit)

      expect { unit.destroy }.to change(UnitAttendance, :count).by(-1)
        .and change(UnitCoverage, :count).by(-1)
    end
  end
end
