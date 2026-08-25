require "rails_helper"

RSpec.describe "Admin resources" do
  describe "authorization" do
    it "hides organization management from plain users" do
      sign_in create(:user)

      get organizations_path
      expect(response).to redirect_to(root_path)

      get juleica_requirements_path
      expect(response).to redirect_to(root_path)

      get users_path
      expect(response).to redirect_to(root_path)
    end

    it "allows admins to manage them" do
      sign_in create(:user, :admin)

      get organizations_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "organizations CRUD" do
    before { sign_in create(:user, :admin) }

    it "creates an organization" do
      expect {
        post organizations_path, params: { organization: { name: "St. Peter's", description: "" } }
      }.to change(Organization, :count).by(1)
    end

    it "renders the new form" do
      get new_organization_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the edit form" do
      get edit_organization_path(create(:organization))

      expect(response).to have_http_status(:ok)
    end

    it "updates an organization" do
      organization = create(:organization, name: "Old Name")

      patch organization_path(organization), params: { organization: { name: "New Name" } }

      aggregate_failures do
        expect(response).to redirect_to(organizations_path)
        expect(organization.reload.name).to eq("New Name")
      end
    end

    it "rejects blank names" do
      post organizations_path, params: { organization: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "deletes an organization without courses" do
      organization = create(:organization)

      expect {
        delete organization_path(organization)
      }.to change(Organization, :count).by(-1)

      expect(response).to redirect_to(organizations_path)
    end

    it "protects organizations with courses from deletion" do
      organization = create(:organization)
      create(:course, organization: organization)

      delete organization_path(organization)

      expect(response).to redirect_to(organizations_path)
      follow_redirect!
      expect(flash[:alert]).to be_present
      expect(Organization.exists?(organization.id)).to be(true)
    end

    it "shows member roles on the organization page" do
      organization = create(:organization)
      user = create(:user, email: "member@example.com")
      create(:organization_membership, :organiser, user: user, organization: organization)

      get organization_path(organization)

      aggregate_failures do
        expect(response.body).to include("member@example.com")
        expect(response.body).to include(">organiser</span>")
      end
    end
  end

  describe "juleica requirements CRUD" do
    before { sign_in create(:user, :admin) }

    it "renders the index" do
      create(:juleica_requirement, name: "Group Leadership")

      get juleica_requirements_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Group Leadership")
      end
    end

    it "renders the detail page with covering courses" do
      requirement = create(:juleica_requirement, name: "Legal Foundations")
      course = create(:course, name: "Law Weekend")
      create(:course_requirement, course: course, juleica_requirement: requirement, hours: 2)

      get juleica_requirement_path(requirement)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Law Weekend")
        expect(response.body).to include("2 h")
      end
    end

    it "renders the new form" do
      get new_juleica_requirement_path

      expect(response).to have_http_status(:ok)
    end

    it "renders the edit form" do
      get edit_juleica_requirement_path(create(:juleica_requirement))

      expect(response).to have_http_status(:ok)
    end

    it "creates a requirement" do
      expect {
        post juleica_requirements_path,
             params: { juleica_requirement: { name: "Legal Foundations", required_hours: 4 } }
      }.to change(JuleicaRequirement, :count).by(1)
    end

    it "updates a requirement" do
      requirement = create(:juleica_requirement, required_hours: 4)

      patch juleica_requirement_path(requirement),
            params: { juleica_requirement: { required_hours: 6 } }

      aggregate_failures do
        expect(response).to redirect_to(juleica_requirements_path)
        expect(requirement.reload.required_hours).to eq(6)
      end
    end

    it "rejects zero required hours" do
      post juleica_requirements_path,
           params: { juleica_requirement: { name: "Invalid", required_hours: 0 } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "deletes an unreferenced requirement" do
      requirement = create(:juleica_requirement)

      expect {
        delete juleica_requirement_path(requirement)
      }.to change(JuleicaRequirement, :count).by(-1)

      expect(response).to redirect_to(juleica_requirements_path)
    end

    it "protects requirements referenced by courses from deletion" do
      requirement = create(:juleica_requirement)
      create(:course_requirement, juleica_requirement: requirement)

      expect {
        delete juleica_requirement_path(requirement)
      }.not_to change(JuleicaRequirement, :count)

      expect(response).to redirect_to(juleica_requirements_path)
      follow_redirect!
      expect(flash[:alert]).to be_present
    end
  end

  describe "users management" do
    let(:admin) { create(:user, :admin) }
    let(:organization) { create(:organization, name: "St. Martin's") }

    before { sign_in admin }

    it "renders the index" do
      create(:user, email: "visible@example.com")

      get users_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("visible@example.com")
      end
    end

    it "creates a user with a system role and an organiser membership" do
      expect {
        post users_path, params: {
          user: {
            email: "newbie@example.com",
            password: "sup3rsecret!",
            password_confirmation: "sup3rsecret!",
            role: "user",
            organization_memberships_attributes: {
              "0" => { organization_id: organization.id, role: "organiser" }
            }
          }
        }
      }.to change(User, :count).by(1)

      new_user = User.find_by!(email: "newbie@example.com")
      membership = new_user.organization_memberships.sole
      aggregate_failures do
        expect(new_user.role).to eq("user")
        expect(membership.organization).to eq(organization)
        expect(membership.role).to eq("organiser")
        expect(new_user).to be_staff
      end
    end

    it "grants and revokes organizer roles through the edit form" do
      user = create(:user)
      membership = create(:organization_membership, user: user, organization: organization)

      patch user_path(user), params: {
        user: {
          organization_memberships_attributes: {
            "0" => { id: membership.id, organization_id: organization.id, role: "organiser" }
          }
        }
      }
      expect(membership.reload.role).to eq("organiser")

      patch user_path(user), params: {
        user: {
          organization_memberships_attributes: {
            "0" => { id: membership.id, organization_id: organization.id, role: "" }
          }
        }
      }

      aggregate_failures do
        expect(user.organization_memberships.exists?(membership.id)).to be(false)
        expect(user.reload).not_to be_organiser
      end
    end

    it "renders the edit form with a role select per organization" do
      user = create(:user)
      create(:organization_membership, :organiser, user: user, organization: organization)

      get edit_user_path(user)

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(CGI.escapeHTML(organization.name))
        expect(response.body).to include("Organiser")
        expect(response.body).to include('selected="selected"')
      end
    end

    it "renders the new form with a role select for every organization" do
      organization
      create(:organization, name: "Church B")

      get new_user_path

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body.scan("Not a member").size).to eq(2)
      end
    end

    it "deletes another user" do
      user = create(:user)

      expect {
        delete user_path(user)
      }.to change(User, :count).by(-1)

      expect(response).to redirect_to(users_path)
    end

    it "blocks admins from deleting their own account" do
      expect {
        delete user_path(admin)
      }.not_to change(User, :count)

      expect(response).to redirect_to(users_path)
      follow_redirect!
      expect(flash[:alert]).to include("cannot delete your own account")
    end

    it "updates system role without requiring a password" do
      user = create(:user)
      other_organization = create(:organization, name: "St. Peter's")

      patch user_path(user), params: {
        user: {
          role: "admin",
          password: "",
          password_confirmation: "",
          organization_memberships_attributes: {
            "0" => { organization_id: other_organization.id, role: "" }
          }
        }
      }

      aggregate_failures do
        expect(user.reload).to be_admin
        expect(user.organizations).to be_empty
      end
    end
  end
end
