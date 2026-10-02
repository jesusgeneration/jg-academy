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

CourseAttendance.destroy_all
CourseCoverage.destroy_all
Course.destroy_all
Content.where(content_type: :detail).delete_all
Content.where(content_type: :section).delete_all
Content.where(content_type: :level).delete_all

JSON.parse(File.read(Rails.root.join("db/seeds_data/contents.json"))).each_with_index do |entry, level_position|
  level = Content.create!(parent: nil, title: entry["title"], content_type: :level, position: level_position)

  entry.fetch("sections").each_with_index do |section_entry, section_position|
    section = Content.create!(parent: level, title: section_entry["title"], content_type: :section, position: section_position)

    section_entry.fetch("details").each_with_index do |title, detail_position|
      Content.create!(parent: section, title:, content_type: :detail, position: detail_position)
    end
  end
end

first_level = Content.level.ordered.first
first_section = first_level.children.ordered.first
first_detail = Content.detail.ordered.first

Course.where(name: [ "Youth Leadership Weekend 2026", "Games & Group Work Weekend", "Safeguarding Weekend" ]).destroy_all

youth_weekend = Course.create!(
  name: "Youth Leadership Weekend 2026",
  description: "Foundations for new youth leaders.",
  starts_at: Time.zone.parse("2026-10-10 18:00"),
  ends_at: Time.zone.parse("2026-10-11 17:00"),
  location: "Parish Hall, St. Martin's",
  organization: st_martins
)
CourseCoverage.create!(course: youth_weekend, content: first_level)

games_weekend = Course.create!(
  name: "Games & Group Work Weekend",
  description: "Practical games and group dynamics.",
  starts_at: Time.zone.parse("2026-11-07 18:00"),
  ends_at: Time.zone.parse("2026-11-08 17:00"),
  location: "Community Center",
  organization: st_peters
)
CourseCoverage.create!(course: games_weekend, content: first_section)

safeguarding_weekend = Course.create!(
  name: "Safeguarding Weekend",
  description: "Child protection training with certificate.",
  starts_at: Time.zone.parse("2026-11-21 09:00"),
  ends_at: Time.zone.parse("2026-11-22 17:00"),
  location: "St. Peter's North",
  organization: st_peters
)
CourseCoverage.create!(course: safeguarding_weekend, content: first_detail)

CourseAttendance.create!(course: youth_weekend, user: organiser, status: :attended)
CourseAttendance.create!(course: youth_weekend, user: alice, status: :attended)
CourseAttendance.create!(course: games_weekend, user: alice, status: :attended)
CourseAttendance.create!(course: safeguarding_weekend, user: alice, status: :registered)
CourseAttendance.create!(course: youth_weekend, user: bob, status: :attended)

puts "Seed complete. Sign in as admin@example.com / organiser@example.com / alice@example.com (password123)"
