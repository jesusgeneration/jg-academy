require "rails_helper"

RSpec.describe Unit, "attendance inheritance" do
  describe ".inherited_status" do
    it "maps attended to registered and keeps all other statuses" do
      aggregate_failures do
        expect(described_class.inherited_status("attended")).to eq("registered")
        expect(described_class.inherited_status("registered")).to eq("registered")
        expect(described_class.inherited_status("cancelled")).to eq("cancelled")
        expect(described_class.inherited_status("no_show")).to eq("no_show")
      end
    end
  end

  describe "#attendance_inheritance_preview" do
    let(:program) { create(:program) }
    let(:unit) { create(:unit, program: program) }

    it "lists program participants as additions with mapped statuses" do
      added = create(:user)
      create(:program_attendance, :attended, program: program, user: added)

      preview = unit.attendance_inheritance_preview

      aggregate_failures do
        expect(preview[:add].map(&:user)).to eq([ added ])
        expect(preview[:conflicts]).to be_empty
        expect(preview[:unchanged]).to eq(0)
      end
    end

    it "marks already matching entries as unchanged" do
      user = create(:user)
      create(:program_attendance, program: program, user: user)
      create(:unit_attendance, unit: unit, user: user, status: :registered)
      create(:program_attendance, :attended, program: program, user: create(:user))

      preview = unit.attendance_inheritance_preview

      aggregate_failures do
        expect(preview[:add].size).to eq(1)
        expect(preview[:conflicts]).to be_empty
        expect(preview[:unchanged]).to eq(1)
      end
    end

    it "flags differing entries as conflicts with the mapped status" do
      user = create(:user)
      create(:program_attendance, :attended, program: program, user: user)
      unit_attendance = create(:unit_attendance, unit: unit, user: user, status: :cancelled)

      preview = unit.attendance_inheritance_preview

      aggregate_failures do
        expect(preview[:add]).to be_empty
        expect(preview[:unchanged]).to eq(0)
        expect(preview[:conflicts].size).to eq(1)
        conflict = preview[:conflicts].sole
        expect(conflict[:user]).to eq(user)
        expect(conflict[:unit_attendance]).to eq(unit_attendance)
        expect(conflict[:mapped_status]).to eq("registered")
      end
    end

    it "never removes unit entries missing from the program" do
      unit_only = create(:user)
      create(:unit_attendance, unit: unit, user: unit_only)

      preview = unit.attendance_inheritance_preview

      aggregate_failures do
        expect(preview[:add]).to be_empty
        expect(preview[:conflicts]).to be_empty
        expect(preview[:unchanged]).to eq(0)
      end
    end
  end
end
