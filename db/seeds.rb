puts "Seeding jg-academy..."

def confirmed_user(email:, role: :user)
  User.find_or_create_by!(email: email) do |user|
    user.password = "password123"
    user.role = role
    user.skip_confirmation!
  end
end

admin = confirmed_user(email: "admin@example.com", role: :admin)
organiser = confirmed_user(email: "organiser@example.com", role: :user)
alice = confirmed_user(email: "alice@example.com")
bob = confirmed_user(email: "bob@example.com")

st_martins = Organization.find_or_create_by!(name: "St. Martin's") do |org|
  org.description = "Catholic parish in the city center."
end
st_peters = Organization.find_or_create_by!(name: "St. Peter's") do |org|
  org.description = "Evangelical congregation in the north."
end

def membership_for(user, organization, role)
  membership = OrganizationMembership.find_or_create_by!(user: user, organization: organization)
  membership.update!(role: role) unless membership.role == role
end

membership_for(organiser, st_martins, :organiser)
membership_for(organiser, st_peters, :member)
membership_for(alice, st_martins, :member)
membership_for(alice, st_peters, :member)
membership_for(bob, st_martins, :member)

group_leadership = JuleicaRequirement.find_or_create_by!(name: "Group Leadership") do |req|
  req.required_hours = 8
  req.description = "Leading and moderating youth groups."
end
legal_foundations = JuleicaRequirement.find_or_create_by!(name: "Legal Foundations") do |req|
  req.required_hours = 4
  req.description = "Child protection law and liability basics."
end
child_protection = JuleicaRequirement.find_or_create_by!(name: "Child Protection") do |req|
  req.required_hours = 4
  req.description = "Recognising and preventing abuse."
end
youth_methods = JuleicaRequirement.find_or_create_by!(name: "Youth Work Methods") do |req|
  req.required_hours = 8
  req.description = "Practical methods for everyday youth work."
end

CourseAttendance.where(user: alice).destroy_all
CourseAttendance.where(user: bob).destroy_all
[ Course.find_by(name: "Youth Leadership Weekend 2026"),
 Course.find_by(name: "Games & Group Work Weekend"),
 Course.find_by(name: "Safeguarding Weekend") ].compact.each(&:destroy)

youth_weekend = Course.create!(
  name: "Youth Leadership Weekend 2026",
  description: "Foundations for new youth leaders.",
  starts_at: Time.zone.parse("2026-10-10 18:00"),
  ends_at: Time.zone.parse("2026-10-11 17:00"),
  location: "Parish Hall, St. Martin's",
  organization: st_martins
)
CourseRequirement.create!(course: youth_weekend, juleica_requirement: group_leadership, hours: 4)
CourseRequirement.create!(course: youth_weekend, juleica_requirement: legal_foundations, hours: 2)

games_weekend = Course.create!(
  name: "Games & Group Work Weekend",
  description: "Practical games and group dynamics.",
  starts_at: Time.zone.parse("2026-11-07 18:00"),
  ends_at: Time.zone.parse("2026-11-08 17:00"),
  location: "Community Center",
  organization: st_peters
)
CourseRequirement.create!(course: games_weekend, juleica_requirement: group_leadership, hours: 4)
CourseRequirement.create!(course: games_weekend, juleica_requirement: youth_methods, hours: 6)

safeguarding_weekend = Course.create!(
  name: "Safeguarding Weekend",
  description: "Child protection training with certificate.",
  starts_at: Time.zone.parse("2026-11-21 09:00"),
  ends_at: Time.zone.parse("2026-11-22 17:00"),
  location: "St. Peter's North",
  organization: st_peters
)
CourseRequirement.create!(course: safeguarding_weekend, juleica_requirement: child_protection, hours: 4)

CourseAttendance.create!(course: youth_weekend, user: organiser, status: :attended)
CourseAttendance.create!(course: youth_weekend, user: alice, status: :attended)
CourseAttendance.create!(course: games_weekend, user: alice, status: :attended)
CourseAttendance.create!(course: safeguarding_weekend, user: alice, status: :registered)
CourseAttendance.create!(course: youth_weekend, user: bob, status: :attended)

puts "Seed complete. Sign in as admin@example.com / organiser@example.com / alice@example.com (password123)"
