require "rails_helper"

RSpec.describe Program do
  describe "validations" do
    it "requires a name, organization and kind" do
      expect(build(:program)).to be_valid
      expect(build(:program, name: nil)).not_to be_valid
      expect(build(:program, organization: nil)).not_to be_valid
      expect(build(:program, kind: nil)).not_to be_valid
    end

    it "defines all program kinds" do
      expect(described_class.kinds).to eq(
        "schooling" => 0,
        "freizeit" => 1,
        "seminar_day" => 2,
        "youth_weekend" => 3,
        "staff_preparation" => 4
      )
    end
  end

  describe "associations" do
    it "restricts deletion while units exist" do
      program = create(:program)
      create(:unit, program: program)

      expect(program.destroy).to be(false)
      expect(Program.exists?(program.id)).to be(true)
    end
  end

  describe "date tabs" do
    it "lists programs with an upcoming unit as upcoming" do
      upcoming_program = create(:program)
      create(:unit, program: upcoming_program)
      past_program = create(:program)
      create(:unit, :past, program: past_program)

      expect(Program.upcoming).to contain_exactly(upcoming_program)
    end

    it "lists programs with past but no upcoming units as past" do
      past_program = create(:program)
      create(:unit, :past, program: past_program)
      create(:unit, program: past_program, starts_at: nil, ends_at: nil)
      upcoming_program = create(:program)
      create(:unit, :past, program: upcoming_program)
      create(:unit, program: upcoming_program)

      expect(Program.past).to contain_exactly(past_program)
    end

    it "lists empty and unscheduled-only programs as planned" do
      empty_program = create(:program)
      unscheduled_program = create(:program)
      create(:unit, program: unscheduled_program, starts_at: nil, ends_at: nil)
      scheduled_program = create(:program)
      create(:unit, program: scheduled_program)

      expect(Program.planned).to contain_exactly(empty_program, unscheduled_program)
    end
  end
end
