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

  it "orders by program count, then member count, then name" do
    busy_few_members = create(:organization, name: "Busy Few")
    create_list(:program, 2, organization: busy_few_members)
    create(:organization_membership, organization: busy_few_members)
    busy_many_members = create(:organization, name: "Busy Many")
    create_list(:program, 2, organization: busy_many_members)
    create_list(:organization_membership, 3, organization: busy_many_members)
    quiet_crowded = create(:organization, name: "Quiet Crowded")
    create(:program, organization: quiet_crowded)
    create_list(:organization_membership, 5, organization: quiet_crowded)
    idle = create(:organization, name: "Idle")

    expect(Organization.ordered_by_activity).to eq(
      [ busy_many_members, busy_few_members, quiet_crowded, idle ]
    )
  end
end
