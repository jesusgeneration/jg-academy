FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "person#{n}@example.com" }
    password { "sup3rsecret!" }
    password_confirmation { "sup3rsecret!" }
    confirmed_at { Time.current }
    role { :user }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :admin do
      role { :admin }
    end
  end

  factory :organization do
    sequence(:name) { |n| "St. Martin's #{n}" }
    description { "A cooperating church." }
  end

  factory :organization_membership do
    user
    organization
    role { :member }

    trait :organiser do
      role { :organiser }
    end
  end

  factory :juleica_requirement do
    sequence(:name) { |n| "Requirement #{n}" }
    required_hours { 8 }
    description { nil }
  end

  factory :course do
    association :organization
    sequence(:name) { |n| "Training Weekend #{n}" }
    starts_at { 2.weeks.from_now.beginning_of_day + 18.hours }
    ends_at { starts_at ? starts_at + 2.days : 3.weeks.from_now }
    location { "Parish Hall" }
    description { nil }

    trait :past do
      starts_at { 1.month.ago }
      ends_at { 1.month.ago + 2.days }
    end
  end

  factory :course_requirement do
    association :course
    juleica_requirement
    hours { 4 }
  end

  factory :course_attendance do
    association :course
    user
    status { :registered }

    trait :attended do
      status { :attended }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :no_show do
      status { :no_show }
    end
  end
end
