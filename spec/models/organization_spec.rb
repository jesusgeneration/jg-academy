require "rails_helper"

RSpec.describe Organization do
  it "validates presence of name" do
    expect(build(:organization, name: nil)).not_to be_valid
    expect(build(:organization)).to be_valid
  end

  it "has many users through memberships" do
    organization = create(:organization)
    alice = create(:user)
    bob = create(:user)
    create(:organization_membership, user: alice, organization: organization)
    create(:organization_membership, user: bob, organization: organization)

    expect(organization.users).to contain_exactly(alice, bob)
  end
end
