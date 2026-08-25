require "rails_helper"

RSpec.describe JuleicaRequirement do
  it "validates presence of name" do
    expect(build(:juleica_requirement, name: nil)).not_to be_valid
  end

  it "requires positive required hours" do
    expect(build(:juleica_requirement, required_hours: 0)).not_to be_valid
    expect(build(:juleica_requirement, required_hours: -2)).not_to be_valid
  end

  it "rejects zero required hours at the database level" do
    requirement = create(:juleica_requirement)

    expect {
      requirement.update_column(:required_hours, 0)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "protects referenced requirements from deletion" do
    requirement = create(:juleica_requirement)
    create(:course_requirement, juleica_requirement: requirement)

    result = requirement.destroy

    expect(result).to be(false)
    expect(requirement.errors[:base]).to be_present
  end
end
