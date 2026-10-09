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
end
