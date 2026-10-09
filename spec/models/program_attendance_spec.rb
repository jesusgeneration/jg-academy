require "rails_helper"

RSpec.describe ProgramAttendance do
  describe "validations" do
    it "allows a user to attend a program" do
      attendance = build(:program_attendance)

      expect(attendance).to be_valid
    end

    it "prevents duplicate attendance for the same program" do
      existing = create(:program_attendance)
      duplicate = build(:program_attendance, user: existing.user, program: existing.program)

      expect(duplicate).not_to be_valid
      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "defaults to registered" do
      expect(described_class.new.status).to eq("registered")
    end
  end

  describe "status enum" do
    it "defines all statuses" do
      expect(ProgramAttendance.statuses).to eq(
        "registered" => 0,
        "attended" => 1,
        "cancelled" => 2,
        "no_show" => 3
      )
    end
  end

  describe "associations" do
    it "belongs to user and program" do
      association = described_class.reflect_on_association(:user)
      program_association = described_class.reflect_on_association(:program)

      expect(association.macro).to eq(:belongs_to)
      expect(program_association.macro).to eq(:belongs_to)
    end
  end
end
