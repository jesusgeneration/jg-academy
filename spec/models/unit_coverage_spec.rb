require "rails_helper"

RSpec.describe UnitCoverage do
  it "links a unit to content" do
    expect(build(:unit_coverage)).to be_valid
  end

  it "requires unit and content" do
    expect(build(:unit_coverage, unit: nil)).not_to be_valid
    expect(build(:unit_coverage, content: nil)).not_to be_valid
  end

  it "prevents duplicate unit/content combinations" do
    existing = create(:unit_coverage)
    duplicate = build(:unit_coverage, unit: existing.unit, content: existing.content)

    expect(duplicate).not_to be_valid
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same content to be covered by multiple units" do
    content = create(:content, :detail)
    create(:unit_coverage, content: content)
    create(:unit_coverage, content: content)

    expect(content.units.count).to eq(2)
  end

  it "allows a unit to cover multiple contents" do
    unit = create(:unit)
    create(:unit_coverage, unit: unit)
    create(:unit_coverage, unit: unit)

    expect(unit.covered_contents.count).to eq(2)
  end
end
