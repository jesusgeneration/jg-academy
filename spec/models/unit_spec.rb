require "rails_helper"

RSpec.describe Unit do
  describe "validations" do
    it "requires a name, program and dates" do
      expect(build(:unit)).to be_valid
      expect(build(:unit, name: nil)).not_to be_valid
      expect(build(:unit, program: nil)).not_to be_valid
      expect(build(:unit, starts_at: nil)).not_to be_valid
      expect(build(:unit, ends_at: nil)).not_to be_valid
    end

    it "rejects end before start" do
      unit = build(:unit, starts_at: 2.weeks.from_now, ends_at: 1.week.from_now)

      expect(unit).not_to be_valid
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
