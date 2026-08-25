require "rails_helper"

RSpec.describe OrganizationMembership do
  it "belongs to a user and an organization" do
    membership = build(:organization_membership)

    expect(membership).to be_valid
    expect(membership.user).to be_present
    expect(membership.organization).to be_present
  end

  it "prevents duplicate memberships" do
    existing = create(:organization_membership)
    duplicate = build(:organization_membership, user: existing.user, organization: existing.organization)

    expect(duplicate).not_to be_valid
    expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
